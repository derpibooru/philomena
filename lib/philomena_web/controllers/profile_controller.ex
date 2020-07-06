defmodule PhilomenaWeb.ProfileController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias Philomena.Elasticsearch
  alias PhilomenaWeb.TextileRenderer
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
  alias Philomena.Polymorphic
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
      commission: [sheet_image: :tags, items: [example_image: :tags]]
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
        _ in fragment("SELECT count(*) FROM users WHERE watched_tag_ids @> ARRAY[?]", t.id)
      )
      |> select([t, c], {t.id, c.count})
      |> Repo.all()
      |> Map.new()

    recent_artwork = recent_artwork(conn, tags)

    recent_comments =
      Elasticsearch.search_records(
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
        %{page_size: 3},
        Comment |> preload(user: [awards: :badge], image: :tags)
      )
      |> Enum.filter(&Canada.Can.can?(current_user, :show, &1.image))

    recent_comments =
      recent_comments
      |> TextileRenderer.render_collection(conn)
      |> Enum.zip(recent_comments)

    recent_posts =
      Elasticsearch.search_records(
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
        %{page_size: 6},
        Post |> preload(user: [awards: :badge], topic: :forum)
      )
      |> Enum.filter(&Canada.Can.can?(current_user, :show, &1.topic))

    about_me = TextileRenderer.render_one(%{body: user.description || ""}, conn)

    scratchpad = TextileRenderer.render_one(%{body: user.scratchpad || ""}, conn)

    commission_information = commission_info(user.commission, conn)

    recent_galleries =
      Gallery
      |> where(creator_id: ^user.id)
      |> preload([:creator, thumbnail: :tags])
      |> limit(4)
      |> Repo.all()

    statistics = calculate_statistics(user)

    interactions =
      Interactions.user_interactions([recent_uploads, recent_faves, recent_artwork], current_user)

    forced = user.forced_filter

    bans =
      Bans.User
      |> where(user_id: ^user.id)
      |> Repo.all()
      |> Enum.reject(&String.contains?(&1.note || "", "discourage"))

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
      |> where([us], us.day > ^(now - 89))
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
    Enum.map(89..0, &(map_fetch(mapping[&1], stat_name) || 0))
  end

  defp map_fetch(nil, _field_name), do: nil
  defp map_fetch(map, field_name), do: Map.get(map, field_name)

  defp commission_info(%{information: info}, conn) when info not in [nil, ""],
    do: TextileRenderer.render_one(%{body: info}, conn)

  defp commission_info(_commission, _conn), do: ""

  defp tags([]), do: []
  defp tags(links), do: Enum.map(links, & &1.tag) |> Enum.reject(&is_nil/1)

  defp recent_artwork(_conn, []), do: []

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
    case Canada.Can.can?(conn.assigns.current_user, :index, User) do
      true ->
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

      _false ->
        conn
    end
  end

  defp set_mod_notes(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, ModNote) do
      true ->
        user = conn.assigns.user

        mod_notes =
          ModNote
          |> where(notable_type: "User", notable_id: ^user.id)
          |> order_by(desc: :id)
          |> preload(:moderator)
          |> Repo.all()
          |> Polymorphic.load_polymorphic(notable: [notable_id: :notable_type])

        mod_notes =
          mod_notes
          |> TextileRenderer.render_collection(conn)
          |> Enum.zip(mod_notes)

        assign(conn, :mod_notes, mod_notes)

      _false ->
        conn
    end
  end
end
