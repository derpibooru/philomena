defmodule PhilomenaWeb.ProfileController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias PhilomenaQuery.Search
  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.UserStatistics.UserStatistic
  alias Philomena.Users.User
  alias Philomena.Bans
  alias Philomena.Galleries.Gallery
  alias Philomena.Posts.Post
  alias Philomena.Comments.Comment
  alias Philomena.Interactions
  alias Philomena.Tags.Tag
  alias Philomena.UserIps.UserIp
  alias Philomena.UserFingerprints.UserFingerprint
  alias Philomena.ModNotes.ModNote
  alias Philomena.ModNotes
  alias Philomena.Images.Image
  alias Philomena.Repo
  import Ecto.Query

  plug :load_and_authorize_resource,
    model: User,
    only: :show,
    id_field: "slug",
    preload: [
      awards: [:badge, :awarded_by],
      public_links: :tag,
      verified_links: :tag,
      commission: [
        sheet_image: [:sources, tags: :aliases],
        items: [example_image: [:sources, tags: :aliases]]
      ]
    ]

  plug :set_admin_metadata
  plug :set_mod_notes

  def show(conn, _params) do
    current_filter = conn.assigns.current_filter
    current_user = conn.assigns.current_user
    user = Repo.preload(conn.assigns.user, [:forced_filter])

    {:ok, {recent_uploads, _tags}} =
      ImageLoader.search_string(
        conn,
        "uploader_id:#{user.id}",
        pagination: %{page_number: 1, page_size: 4}
      )

    {:ok, {recent_faves, _tags}} =
      ImageLoader.search_string(
        conn,
        "faved_by_id:#{user.id}",
        pagination: %{page_number: 1, page_size: 4}
      )

    tags = tags(conn.assigns.user.public_links)

    all_tag_ids =
      conn.assigns.user.verified_links
      |> tags()
      |> Enum.map(& &1.id)

    watcher_counts =
      Tag
      |> where([t], t.id in ^all_tag_ids)
      |> join(
        :inner_lateral,
        [t],
        _ in fragment("SELECT count(*) FROM users WHERE watched_tag_ids @> ARRAY[?]", t.id),
        on: true
      )
      |> select([t, c], {t.id, c.count})
      |> Repo.all()
      |> Map.new()

    recent_artwork = recent_artwork(conn, tags)

    recent_comments =
      Search.search_definition(
        Comment,
        %{
          query: %{
            bool: %{
              must: [
                %{term: %{user_id: user.id}},
                %{term: %{anonymous: false}},
                %{term: %{hidden_from_users: false}}
              ],
              must_not: [
                %{terms: %{image_tag_ids: current_filter.hidden_tag_ids}}
              ]
            }
          },
          sort: %{posted_at: :desc}
        },
        %{page_size: 3}
      )

    recent_posts =
      Search.search_definition(
        Post,
        %{
          query: %{
            bool: %{
              must: [
                %{term: %{user_id: user.id}},
                %{term: %{anonymous: false}},
                %{term: %{deleted: false}},
                %{term: %{access_level: "normal"}}
              ]
            }
          },
          sort: %{created_at: :desc}
        },
        %{page_size: 6}
      )

    [recent_uploads, recent_faves, recent_artwork, recent_comments, recent_posts] =
      Search.msearch_records(
        [recent_uploads, recent_faves, recent_artwork, recent_comments, recent_posts],
        [
          preload(Image, [:sources, tags: :aliases]),
          preload(Image, [:sources, tags: :aliases]),
          preload(Image, [:sources, tags: :aliases]),
          preload(Comment, [
            :deleted_by,
            user: [awards: :badge],
            image: [:sources, tags: :aliases]
          ]),
          preload(Post, [:deleted_by, user: [awards: :badge], topic: :forum])
        ]
      )

    recent_posts = Enum.filter(recent_posts, &Canada.Can.can?(current_user, :show, &1.topic))

    recent_comments =
      recent_comments
      |> Enum.filter(&Canada.Can.can?(current_user, :show, &1.image))
      |> MarkdownRenderer.render_collection(conn)
      |> Enum.zip(recent_comments)

    about_me = MarkdownRenderer.render_one(%{body: user.description || ""}, conn)

    scratchpad = MarkdownRenderer.render_one(%{body: user.scratchpad || ""}, conn)

    commission_information = commission_info(user.commission, conn)

    recent_galleries =
      Gallery
      |> where(creator_id: ^user.id)
      |> preload([:creator, thumbnail: [:sources, tags: :aliases]])
      |> limit(4)
      |> Repo.all()

    statistics = calculate_statistics(user)

    interactions =
      Interactions.user_interactions([recent_uploads, recent_faves, recent_artwork], current_user)

    forced = user.forced_filter

    bans =
      Bans.User
      |> where(user_id: ^user.id)
      |> order_by(desc: :created_at)
      |> Repo.all()

    render(
      conn,
      "show.html",
      user: user,
      interactions: interactions,
      commission_information: commission_information,
      recent_artwork: recent_artwork,
      recent_uploads: recent_uploads,
      recent_faves: recent_faves,
      recent_comments: recent_comments,
      recent_posts: recent_posts,
      recent_galleries: recent_galleries,
      statistics: statistics,
      watcher_counts: watcher_counts,
      about_me: about_me,
      scratchpad: scratchpad,
      tags: tags,
      forced: forced,
      bans: bans,
      layout_class: "layout--medium",
      title: "#{user.name}'s profile"
    )
  end

  defp calculate_statistics(user) do
    now =
      DateTime.utc_now()
      |> DateTime.to_unix(:second)
      |> div(86400)

    last_90 =
      UserStatistic
      |> where(user_id: ^user.id)
      |> where([us], us.day >= ^(now - 89))
      |> Repo.all()
      |> Map.new(&{now - &1.day, &1})

    %{
      uploads: individual_stat(last_90, :uploads),
      images_favourited: individual_stat(last_90, :images_favourited),
      comments_posted: individual_stat(last_90, :comments_posted),
      votes_cast: individual_stat(last_90, :votes_cast),
      metadata_updates: individual_stat(last_90, :metadata_updates),
      forum_posts: individual_stat(last_90, :forum_posts)
    }
  end

  defp individual_stat(mapping, stat_name) do
    Enum.map(89..0//-1, &(map_fetch(mapping[&1], stat_name) || 0))
  end

  defp map_fetch(nil, _field_name), do: nil
  defp map_fetch(map, field_name), do: Map.get(map, field_name)

  defp commission_info(%{information: info}, conn)
       when info not in [nil, ""],
       do: MarkdownRenderer.render_one(%{body: info}, conn)

  defp commission_info(_commission, _conn), do: ""

  defp tags([]), do: []
  defp tags(links), do: Enum.map(links, & &1.tag) |> Enum.reject(&is_nil/1)

  defp recent_artwork(_conn, []) do
    Search.search_definition(Image, %{query: %{match_none: %{}}})
  end

  defp recent_artwork(conn, tags) do
    {images, _tags} =
      ImageLoader.query(
        conn,
        %{terms: %{tag_ids: Enum.map(tags, & &1.id)}},
        pagination: %{page_number: 1, page_size: 4}
      )

    images
  end

  defp set_admin_metadata(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :index, User) do
      user = Repo.preload(conn.assigns.user, [:current_filter])
      filter = user.current_filter

      last_ip =
        UserIp
        |> where(user_id: ^user.id)
        |> order_by(desc: :updated_at)
        |> limit(1)
        |> Repo.one()

      last_fp =
        UserFingerprint
        |> where(user_id: ^user.id)
        |> order_by(desc: :updated_at)
        |> limit(1)
        |> Repo.one()

      conn
      |> assign(:filter, filter)
      |> assign(:last_ip, last_ip)
      |> assign(:last_fp, last_fp)
    else
      conn
    end
  end

  defp set_mod_notes(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :index, ModNote) do
      renderer = &MarkdownRenderer.render_collection(&1, conn)
      user = conn.assigns.user

      mod_notes = ModNotes.list_all_mod_notes_by_type_and_id("User", user.id, renderer)
      assign(conn, :mod_notes, mod_notes)
    else
      conn
    end
  end
end
