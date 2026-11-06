defmodule Philomena.Profiles do
  @moduledoc """
  Public profile pages and sensitive staff-only account metadata, IP histories,
  and fingerprint histories.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization, only: [authorize: 3]

  alias Philomena.Attribution.Actor
  alias Philomena.Bans
  alias Philomena.Comments
  alias Philomena.Comments.Comment
  alias Philomena.Filters.Filter
  alias Philomena.Galleries.Gallery
  alias Philomena.Images.Image
  alias Philomena.Images.Search, as: ImageSearch
  alias Philomena.Images.Search.Scope
  alias Philomena.Interactions
  alias Philomena.ModNotes
  alias Philomena.Posts.Post
  alias Philomena.Profiles.AdminMetadata
  alias Philomena.Profiles.FingerprintHistory
  alias Philomena.Profiles.IpHistory
  alias Philomena.Profiles.ProfilePage
  alias Philomena.Repo
  alias Philomena.Tags.Tag
  alias Philomena.UserFingerprints
  alias Philomena.UserIps
  alias Philomena.UserNameChanges
  alias Philomena.Users
  alias Philomena.Users.User
  alias Philomena.UserStatistics.UserStatistic
  alias PhilomenaQuery.Search

  @name_history_pagination %{page: 1, page_size: 250}

  @profile_preloads [
    :forced_filter,
    awards: [:badge, :awarded_by],
    public_links: :tag,
    verified_links: :tag,
    commission: [
      sheet_image: [:sources, tags: :aliases],
      items: [example_image: [:sources, tags: :aliases]]
    ]
  ]

  defp assemble_profile_page(actor, scope, current_filter, user) do
    {:ok, {recent_uploads_def, _tags}} =
      ImageSearch.search_string(
        actor,
        scope,
        ImageSearch.default_sort(),
        "uploader_id:#{user.id}",
        pagination: %{page_number: 1, page_size: 4}
      )

    {:ok, {recent_faves_def, _tags}} =
      ImageSearch.search_string(
        actor,
        scope,
        ImageSearch.default_sort(),
        "faved_by_id:#{user.id}",
        pagination: %{page_number: 1, page_size: 4}
      )

    tags = link_tags(user.public_links)

    verified_tag_ids =
      user.verified_links
      |> link_tags()
      |> Enum.map(& &1.id)

    recent_artwork_def = recent_artwork_definition(actor, scope, tags)

    recent_comments_def =
      Comments.comment_search_definition(
        actor,
        current_filter,
        [
          %{term: %{author_id: user.id}},
          %{term: %{hidden_from_users: false}}
        ],
        pagination: %{page_size: 3},
        show_hidden: false
      )

    recent_posts_def =
      Search.search_definition(
        Post,
        %{
          query: %{
            bool: %{
              must: [
                %{term: %{author_id: user.id}},
                %{term: %{hidden_from_users: false}},
                %{term: %{access_level: "normal"}}
              ]
            }
          },
          sort: %{created_at: :desc}
        },
        %{page_size: 6}
      )

    %{
      recent_uploads: recent_uploads,
      recent_faves: recent_faves,
      recent_artwork: recent_artwork,
      recent_comments: recent_comments,
      recent_posts: recent_posts
    } =
      Search.msearch_records(
        recent_uploads: {recent_uploads_def, preload(Image, [:sources, tags: :aliases])},
        recent_faves: {recent_faves_def, preload(Image, [:sources, tags: :aliases])},
        recent_artwork: {recent_artwork_def, preload(Image, [:sources, tags: :aliases])},
        recent_comments:
          {recent_comments_def,
           preload(Comment, [
             :deleted_by,
             user: [awards: :badge],
             image: [:sources, tags: :aliases]
           ])},
        recent_posts:
          {recent_posts_def, preload(Post, [:deleted_by, user: [awards: :badge], topic: :forum])}
      )

    recent_posts = Enum.filter(recent_posts, &(authorize(actor, :show, &1.topic) == :ok))
    recent_comments = Enum.filter(recent_comments, &(authorize(actor, :show, &1.image) == :ok))

    recent_galleries =
      Gallery
      |> where(user_id: ^user.id, anonymous: false)
      |> preload(thumbnail: [:sources, tags: :aliases])
      |> limit(4)
      |> Repo.all()

    interactions =
      Interactions.user_interactions(actor, [recent_uploads, recent_faves, recent_artwork])

    %ProfilePage{
      user: user,
      recent_uploads: recent_uploads,
      recent_faves: recent_faves,
      recent_artwork: recent_artwork,
      recent_comments: recent_comments,
      recent_posts: recent_posts,
      recent_galleries: recent_galleries,
      statistics: calculate_statistics(user),
      watcher_counts: watcher_counts(verified_tag_ids),
      tags: tags,
      interactions: interactions,
      bans: user_bans(user)
    }
  end

  defp recent_artwork_definition(_actor, _scope, []) do
    Search.search_definition(Image, %{query: %{match_none: %{}}})
  end

  defp recent_artwork_definition(actor, scope, tags) do
    {definition, _tags} =
      ImageSearch.query(
        actor,
        scope,
        ImageSearch.default_sort(),
        %{terms: %{tag_ids: Enum.map(tags, & &1.id)}},
        pagination: %{page_number: 1, page_size: 4}
      )

    definition
  end

  defp link_tags([]), do: []
  defp link_tags(links), do: links |> Enum.map(& &1.tag) |> Enum.reject(&is_nil/1)

  defp watcher_counts(tag_ids) do
    Tag
    |> where([t], t.id in ^tag_ids)
    |> join(
      :inner_lateral,
      [t],
      _ in fragment("SELECT count(*) FROM users WHERE watched_tag_ids @> ARRAY[?]", t.id),
      on: true
    )
    |> select([t, c], {t.id, c.count})
    |> Repo.all()
    |> Map.new()
  end

  defp user_bans(user) do
    Bans.User
    |> where(user_id: ^user.id)
    |> order_by(desc: :created_at)
    |> Repo.all()
  end

  defp calculate_statistics(user) do
    today = Date.utc_today()

    last_90 =
      UserStatistic
      |> where(user_id: ^user.id)
      |> where([us], us.day >= ^Date.add(today, -89))
      |> Repo.all()
      |> Map.new(&{Date.diff(today, &1.day), &1})

    %{
      images_count: individual_stat(last_90, :images_count),
      image_faves_count: individual_stat(last_90, :image_faves_count),
      comments_count: individual_stat(last_90, :comments_count),
      image_votes_count: individual_stat(last_90, :image_votes_count),
      metadata_updates_count: individual_stat(last_90, :metadata_updates_count),
      posts_count: individual_stat(last_90, :posts_count)
    }
  end

  defp individual_stat(mapping, stat_name) do
    Enum.map(89..0//-1, &(map_fetch(mapping[&1], stat_name) || 0))
  end

  defp map_fetch(nil, _field_name), do: nil
  defp map_fetch(map, field_name), do: Map.get(map, field_name)

  defp load_detailed_profile(actor, slug) do
    with {:ok, user} <- Users.load_profile(actor, slug),
         :ok <- authorize(actor, :show_details, user),
         :ok <- authorize(actor, :show, :identity_metadata) do
      {:ok, user}
    end
  end

  @doc """
  Assembles the public profile page for the user named by `slug`.

  The actor is carried separately from the image-search scope and the profile
  is loaded following `Users.load_profile/3`. `current_filter` scopes the recent comments strip. Posts
  and comments whose parents the actor cannot show are removed after search.
  The loaded user includes its forced filter for the caller's owner/staff-only
  presentation gate.

  Returns `{:ok, %ProfilePage{}}`.

  ## Examples

      iex> show_profile(actor, scope, filter, "somebody")
      {:ok, %ProfilePage{}}

      iex> show_profile(actor, scope, filter, "missing")
      {:error, :not_found}

  """
  @spec show_profile(Actor.t(), Scope.t(), Filter.t(), String.t()) ::
          {:ok, ProfilePage.t()} | {:error, :unauthorized | :not_found}
  def show_profile(
        %Actor{} = actor,
        %Scope{} = scope,
        %Filter{} = current_filter,
        slug
      ) do
    with {:ok, user} <- Users.load_profile(actor, slug) do
      user = Repo.preload(user, @profile_preloads)
      {:ok, assemble_profile_page(actor, scope, current_filter, user)}
    end
  end

  @doc """
  Loads sensitive account metadata about `user` for `actor`.

  The actor must be authorized for `:show_details` on the user and to show
  `:identity_metadata` before the current filter or latest IP and fingerprint
  rows are queried.

  ## Examples

      iex> load_admin_metadata(moderator, user)
      {:ok, %AdminMetadata{}}

      iex> load_admin_metadata(ordinary_user, user)
      {:error, :unauthorized}

  """
  @spec load_admin_metadata(Actor.t(), User.t()) ::
          {:ok, AdminMetadata.t()} | {:error, :unauthorized}
  def load_admin_metadata(%Actor{} = actor, %User{} = user) do
    with :ok <- authorize(actor, :show_details, user),
         :ok <- authorize(actor, :show, :identity_metadata),
         {:ok, last_ip} <- UserIps.latest_for_user(actor, user),
         {:ok, last_fingerprint} <- UserFingerprints.latest_for_user(actor, user) do
      user = Repo.preload(user, [:current_filter])

      {:ok,
       %AdminMetadata{
         filter: user.current_filter,
         last_ip: last_ip,
         last_fingerprint: last_fingerprint
       }}
    end
  end

  @doc """
  Loads up to 250 newest moderation notes on `user` for `actor`, processed
  through `collection_renderer`.

  The profile is loaded and authorized for `:show_details`, then any additional
  ModNotes permissions are checked.

  ## Examples

      iex> load_mod_notes(moderator, user, renderer)
      {:ok, [{%ModNote{}, "rendered"}]}

  """
  @spec load_mod_notes(Actor.t(), User.t(), (list() -> list())) ::
          {:ok, list()} | {:error, :not_found | :unauthorized}
  def load_mod_notes(%Actor{} = actor, %User{} = user, collection_renderer) do
    with :ok <- authorize(actor, :show_details, user) do
      ModNotes.list_for_target(actor, {:user, user.id}, collection_renderer)
    end
  end

  @doc """
  Loads up to 250 newest name changes of `user` for `actor`.

  The profile is loaded and authorized for `:show_details`, then any additional
  UserNameChanges permissions are checked.

  ## Examples

      iex> load_name_changes(moderator, user)
      {:ok, [%UserNameChange{}]}

  """
  @spec load_name_changes(Actor.t(), User.t()) ::
          {:ok, [UserNameChanges.UserNameChange.t()]} | {:error, :unauthorized}
  def load_name_changes(%Actor{} = actor, %User{} = user) do
    with :ok <- authorize(actor, :show_details, user),
         {:ok, page} <- UserNameChanges.load_history(actor, user, @name_history_pagination) do
      {:ok, page.entries}
    end
  end

  @doc """
  Loads a page of IP history for the active profile named by `slug`, plus other
  users seen on the IPs in that page.

  The profile is loaded and authorized for `:show_details`, then the actor is
  authorized to show `:identity_metadata`.

  ## Examples

      iex> list_profile_ip_history(moderator, slug, page: 1, page_size: 25)
      {:ok, %IpHistory{}}

  """
  @spec list_profile_ip_history(Actor.t(), String.t(), Repo.pagination_params()) ::
          {:ok, IpHistory.t()} | {:error, :unauthorized | :not_found}
  def list_profile_ip_history(%Actor{} = actor, slug, pagination) do
    with {:ok, user} <- load_detailed_profile(actor, slug),
         {:ok, {user_ips, other_users}} <-
           UserIps.load_user_history(actor, user, pagination) do
      {:ok, %IpHistory{user: user, user_ips: user_ips, other_users: other_users}}
    end
  end

  @doc """
  Loads a page of fingerprint history for the active profile named by `slug`,
  plus other users seen with the fingerprints in that page.

  The profile is loaded and authorized for `:show_details`, then the actor is
  authorized to show `:identity_metadata`.

  ## Examples

      iex> list_profile_fingerprint_history(moderator, slug, page: 1, page_size: 25)
      {:ok, %FingerprintHistory{}}

  """
  @spec list_profile_fingerprint_history(Actor.t(), String.t(), Repo.pagination_params()) ::
          {:ok, FingerprintHistory.t()} | {:error, :unauthorized | :not_found}
  def list_profile_fingerprint_history(%Actor{} = actor, slug, pagination) do
    with {:ok, user} <- load_detailed_profile(actor, slug),
         {:ok, {user_fingerprints, other_users}} <-
           UserFingerprints.load_user_history(actor, user, pagination) do
      {:ok,
       %FingerprintHistory{
         user: user,
         user_fingerprints: user_fingerprints,
         other_users: other_users
       }}
    end
  end
end
