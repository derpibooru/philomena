defmodule Philomena.ArtistLinks do
  @moduledoc """
  Artist link submission and staff verification workflows.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.ArtistLinks.{
    ArtistLink,
    AutomaticVerifier,
    QueryBuilder,
    QueryForm
  }

  alias Philomena.Attribution.Actor
  alias Philomena.Authorization
  alias Philomena.Badges
  alias Philomena.Loader
  alias Philomena.ModerationLogs
  alias Philomena.ModerationLogs.Paths
  alias Philomena.Multi
  alias Philomena.Repo
  alias Philomena.Tags
  alias Philomena.Users.User

  @artist_link_preloads [:user, :tag, :contacted_by_user]

  defp load_authorized_profile(%Actor{} = actor, action, slug) do
    User
    |> where(slug: ^slug)
    |> where([u], is_nil(u.deleted_at))
    |> Loader.one_and_authorize(actor, action)
  end

  defp load_scoped_artist_link(%Actor{} = actor, action, slug, id) do
    with {:ok, user} <- load_authorized_profile(actor, :show, slug) do
      ArtistLink
      |> where(user_id: ^user.id)
      |> preload(^@artist_link_preloads)
      |> Loader.fetch_and_authorize(actor, action, id)
    end
  end

  defp load_artist_link(%Actor{} = actor, action, id) do
    Loader.fetch_and_authorize(ArtistLink, actor, action, id, @artist_link_preloads)
  end

  @doc """
  Updates all artist links pending verification, by transitioning to link verified state
  or resetting next update time.

  This function is designed for automatic link verification as a background task,
  and is not intended for use from request-facing code.
  """
  @spec run_automatic_verification!() :: :ok
  def run_automatic_verification! do
    Enum.each(AutomaticVerifier.generate_updates(), &Repo.update!/1)
  end

  @doc """
  Lists the artist links belonging to the user named by the profile `slug`, on
  behalf of `actor`.

  ## Examples

      iex> list_artist_links(user_actor, user.slug)
      {:ok, {%User{}, [%ArtistLink{}, ...]}}

      iex> list_artist_links(anonymous_actor, user.slug)
      {:error, :unauthorized}

      iex> list_artist_links(user_actor, invalid_slug)
      {:error, :not_found}

  """
  @spec list_artist_links(Actor.t(), String.t()) ::
          {:ok, {User.t(), [ArtistLink.t()]}} | {:error, :unauthorized | :not_found}
  def list_artist_links(%Actor{} = actor, slug) do
    with {:ok, user} <- load_authorized_profile(actor, :create_links, slug) do
      links =
        ArtistLink
        |> where(user_id: ^user.id)
        |> Repo.all()

      {:ok, {user, links}}
    end
  end

  @doc """
  Returns paginated artist links for the admin listing, on behalf of
  `actor`, newest first, with the moderation associations preloaded.

  The query form filters by artist-link states and `%term%` matches on the
  profile user name or link URI. By default, it lists only links awaiting
  moderation (`unverified`/`link_verified`/`contacted`).

  ## Examples

      iex> list_admin_artist_links(admin, params, pagination)
      {:ok, %Scrivener.Page{}, %Ecto.Changeset{}}

      iex> list_admin_artist_links(user, params, pagination)
      {:error, :unauthorized}

  """
  @spec list_admin_artist_links(Actor.t(), map(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t(ArtistLink.t()), Ecto.Changeset.t()} | {:error, :unauthorized}
  def list_admin_artist_links(%Actor{} = actor, params, pagination) do
    with :ok <- authorize(actor, :index, ArtistLink) do
      {artist_links, changeset} =
        case QueryBuilder.build_query(params) do
          {:ok, query, query_form} ->
            page =
              query
              |> preload([
                :tag,
                :verified_by_user,
                :contacted_by_user,
                user: [:linked_tags, awards: :badge]
              ])
              |> Repo.paginate(pagination)

            {page, QueryForm.changeset(query_form)}

          {:error, changeset} ->
            {Repo.paginate(where(ArtistLink, false), pagination), changeset}
        end

      {:ok, artist_links, changeset}
    end
  end

  @doc """
  Loads the profile user named by `slug` for creating a new artist link, on
  behalf of `actor`.

  ## Examples

      iex> new_artist_link(user_actor, user.slug)
      {:ok, {%User{}, %Ecto.Changeset{}}}

      iex> new_artist_link(admin_actor, other_user.slug)
      {:ok, {%User{}, %Ecto.Changeset{}}}

      iex> new_artist_link(banned_actor, banned_user.slug)
      {:error, :ban}

      iex> new_artist_link(admin_actor, invalid_slug)
      {:error, :not_found}

      iex> new_artist_link(user_actor, other_user.slug)
      {:error, :unauthorized}

  """
  @spec new_artist_link(Actor.t(), String.t()) ::
          {:ok, {User.t(), Ecto.Changeset.t()}}
          | {:error, :ban | :unauthorized | :not_found}
  def new_artist_link(%Actor{} = actor, slug) do
    with :ok <- verify_not_banned(actor),
         {:ok, user} <- load_authorized_profile(actor, :create_links, slug) do
      {:ok, {user, ArtistLink.changeset(%ArtistLink{})}}
    end
  end

  @doc """
  Submits a new artist link for the user named by the profile `slug`, on behalf
  of `actor`, from `attrs`.

  ## Examples

      iex> create_artist_link(user_actor, user.slug, artist_link_params)
      {:ok, {%User{}, %ArtistLink{}}}

      iex> create_artist_link(admin_actor, other_user.slug, artist_link_params)
      {:ok, {%User{}, %ArtistLink{}}}

      iex> create_artist_link(user_actor, user.slug, invalid_params)
      {:error, {%User{}, %Ecto.Changeset{}}}

      iex> create_artist_link(banned_actor, banned_user.slug, artist_link_params)
      {:error, :ban}

      iex> create_artist_link(user_actor, other_user.slug, artist_link_params)
      {:error, :unauthorized}

      iex> create_artist_link(admin_actor, invalid_slug, artist_link_params)
      {:error, :not_found}

  """
  @spec create_artist_link(Actor.t(), String.t(), map()) ::
          {:ok, {User.t(), ArtistLink.t()}}
          | {:error, {User.t(), Ecto.Changeset.t()}}
          | {:error, :ban | :unauthorized | :not_found}
  def create_artist_link(%Actor{} = actor, slug, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_authorized_profile(actor, :create_links, slug),
         {:ok, artist_link} <-
           %ArtistLink{}
           |> ArtistLink.tag_name_changeset(attrs)
           |> Ecto.Changeset.apply_action(:create) do
      tag_names = List.wrap(artist_link.tag_name)

      Multi.new()
      |> Tags.put_canonicalize_tag_name_sets([{:tag, tag_names, []}])
      |> Multi.insert(:artist_link, fn %{canonical_tags: %{tag: tags}} ->
        ArtistLink.creation_changeset(%ArtistLink{}, attrs, user, List.first(tags))
      end)
      |> Multi.transact_with_automatic_retry()
      |> case do
        {:ok, %{artist_link: %ArtistLink{} = artist_link}} ->
          {:ok, {user, artist_link}}

        {:error, :artist_link, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, {user, changeset}}
      end
    end
  end

  @doc """
  Loads the artist link named by `id` under the profile `slug`, on behalf of
  `actor`.

  ## Examples

      iex> show_artist_link(user, user.slug, artist_link_id)
      {:ok, {%User{}, %ArtistLink{}}}

      iex> show_artist_link(admin, other_user.slug, artist_link_id)
      {:ok, {%User{}, %ArtistLink{}}}

      iex> show_artist_link(user, other_user.slug, artist_link_id)
      {:error, :unauthorized}

      iex> show_artist_link(user, invalid_slug, invalid_id)
      {:error, :not_found}

  """
  @spec show_artist_link(Actor.t(), String.t(), Loader.integer_id()) ::
          {:ok, {User.t(), ArtistLink.t()}} | {:error, :unauthorized | :not_found}
  def show_artist_link(%Actor{} = actor, slug, id) do
    with {:ok, artist_link} <- load_scoped_artist_link(actor, :show, slug, id) do
      {:ok, {artist_link.user, artist_link}}
    end
  end

  @doc """
  Loads the artist link named by `id` under the profile `slug` for editing, on
  behalf of `actor`.

  ## Examples

      iex> edit_artist_link(user, user.slug, artist_link_id)
      {:ok, {%ArtistLink{}, %Ecto.Changeset{}}}

      iex> edit_artist_link(admin, other_user.slug, artist_link_id)
      {:ok, {%ArtistLink{}, %Ecto.Changeset{}}}

      iex> edit_artist_link(user, other_user.slug, artist_link_id)
      {:error, :unauthorized}

      iex> edit_artist_link(user, invalid_slug, invalid_id)
      {:error, :not_found}

  """
  @spec edit_artist_link(Actor.t(), String.t(), Loader.integer_id()) ::
          {:ok, {ArtistLink.t(), Ecto.Changeset.t()}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def edit_artist_link(%Actor{} = actor, slug, id) do
    with :ok <- verify_not_banned(actor),
         {:ok, artist_link} <- load_scoped_artist_link(actor, :edit, slug, id) do
      {:ok, {artist_link, ArtistLink.changeset(artist_link)}}
    end
  end

  @doc """
  Updates the artist link named by `id` under the profile `slug`, on behalf of
  `actor`, from `attrs`.

  ## Examples

      iex> update_artist_link(admin, user.slug, artist_link_id, artist_link_params)
      {:ok, {%User{}, %ArtistLink{}}}

      iex> update_artist_link(admin, user.slug, artist_link_id, invalid_params)
      {:error, {%ArtistLink{}, %Ecto.Changeset{}}}

      iex> update_artist_link(admin, user.slug, invalid_id, invalid_params)
      {:error, :not_found}

      iex> update_artist_link(user, user.slug, artist_link_id, artist_link_params)
      {:error, :unauthorized}

  """
  @spec update_artist_link(Actor.t(), String.t(), Loader.integer_id(), map()) ::
          {:ok, {User.t(), ArtistLink.t()}}
          | {:error, {ArtistLink.t(), Ecto.Changeset.t()}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def update_artist_link(%Actor{} = actor, slug, id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, artist_link} <- load_scoped_artist_link(actor, :update, slug, id),
         {:ok, artist_link} <-
           artist_link
           |> ArtistLink.tag_name_changeset(attrs)
           |> Ecto.Changeset.apply_action(:update) do
      tag_names = List.wrap(artist_link.tag_name)

      Multi.new()
      |> Tags.put_canonicalize_tag_name_sets([{:tag, tag_names, []}])
      |> Multi.update(:artist_link, fn %{canonical_tags: %{tag: tags}} ->
        ArtistLink.edit_changeset(artist_link, attrs, List.first(tags))
      end)
      |> Multi.transact_with_automatic_retry()
      |> case do
        {:ok, %{artist_link: %ArtistLink{} = artist_link}} ->
          {:ok, {artist_link.user, artist_link}}

        {:error, :artist_link, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, {artist_link, changeset}}
      end
    end
  end

  @doc """
  Verifies the artist link named by `id`, on behalf of `actor`, transitioning it
  to the verified state and awarding the artist badge to its owner.

  On success a moderation log attributing the update to `actor` is written.

  ## Examples

      iex> create_artist_link_verification(admin, artist_link_id)
      {:ok, %ArtistLink{}}

      iex> create_artist_link_verification(admin, invalid_id)
      {:error, :not_found}

      iex> create_artist_link_verification(user, artist_link_id)
      {:error, :unauthorized}

  """
  @spec create_artist_link_verification(Actor.t(), Loader.integer_id()) ::
          {:ok, ArtistLink.t()}
          | {:error, Authorization.write_error_reason() | :not_found | Ecto.Changeset.t()}
  def create_artist_link_verification(%Actor{user: user} = actor, id) do
    with :ok <- verify_write_access(actor),
         {:ok, artist_link} <- load_artist_link(actor, :verify, id) do
      verify_changeset = ArtistLink.verify_changeset(artist_link, user)

      Multi.new()
      |> Multi.update(:artist_link, verify_changeset)
      |> Badges.put_award_artist_badge(artist_link.user, user)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{artist_link: artist_link} ->
          {
            "Admin.ArtistLink.Verification:create",
            Paths.artist_link_path(artist_link.user, artist_link),
            "Verified artist link #{artist_link.uri} created by #{artist_link.user.name}"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{artist_link: %ArtistLink{} = artist_link}} ->
          {:ok, artist_link}

        {:error, :artist_link, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Rejects the artist link named by `id`, on behalf of `actor`, transitioning it
  to the rejected state.

  On success a moderation log attributing the update to `actor` is written.

  ## Examples

      iex> create_artist_link_reject(admin, artist_link_id)
      {:ok, %ArtistLink{}}

      iex> create_artist_link_reject(admin, invalid_id)
      {:error, :not_found}

      iex> create_artist_link_reject(user, artist_link_id)
      {:error, :unauthorized}

  """
  @spec create_artist_link_reject(Actor.t(), Loader.integer_id()) ::
          {:ok, ArtistLink.t()}
          | {:error, Authorization.write_error_reason() | :not_found | Ecto.Changeset.t()}
  def create_artist_link_reject(%Actor{} = actor, id) do
    with :ok <- verify_write_access(actor),
         {:ok, artist_link} <- load_artist_link(actor, :reject, id) do
      reject_changeset = ArtistLink.reject_changeset(artist_link)

      Multi.new()
      |> Multi.update(:artist_link, reject_changeset)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{artist_link: artist_link} ->
          {
            "Admin.ArtistLink.Reject:create",
            Paths.artist_link_path(artist_link.user, artist_link),
            "Rejected artist link #{artist_link.uri} created by #{artist_link.user.name}"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{artist_link: %ArtistLink{} = artist_link}} ->
          {:ok, artist_link}

        {:error, :artist_link, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Marks the artist link named by `id` as contacted, on behalf of `actor`,
  transitioning it to the contacted state.

  On success a moderation log attributing the update to `actor` is written.

  ## Examples

      iex> create_artist_link_contact(admin, artist_link_id)
      {:ok, %ArtistLink{}}

      iex> create_artist_link_contact(admin, invalid_id)
      {:error, :not_found}

      iex> create_artist_link_contact(user, artist_link_id)
      {:error, :unauthorized}

  """
  @spec create_artist_link_contact(Actor.t(), Loader.integer_id()) ::
          {:ok, ArtistLink.t()}
          | {:error, Authorization.write_error_reason() | :not_found | Ecto.Changeset.t()}
  def create_artist_link_contact(%Actor{user: user} = actor, id) do
    with :ok <- verify_write_access(actor),
         {:ok, artist_link} <- load_artist_link(actor, :contact, id) do
      contact_changeset = ArtistLink.contact_changeset(artist_link, user)

      Multi.new()
      |> Multi.update(:artist_link, contact_changeset)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{artist_link: artist_link} ->
          {
            "Admin.ArtistLink.Contact:create",
            Paths.artist_link_path(artist_link.user, artist_link),
            "Contacted artist #{artist_link.user.name} at #{artist_link.uri}"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{artist_link: %ArtistLink{} = artist_link}} ->
          {:ok, artist_link}

        {:error, :artist_link, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Repoints artist links from one tag to another inside `multi`.

  Links that would duplicate an existing non-rejected target link are removed
  first. Tag aliasing composes this operation instead of writing the
  `artist_links` table directly.
  """
  @spec put_alias_tag(Multi.t(), integer(), integer()) :: Multi.t()
  def put_alias_tag(%Multi{} = multi, source_tag_id, target_tag_id) do
    conflicts =
      from source in ArtistLink,
        join: target in ArtistLink,
        on:
          target.tag_id == ^target_tag_id and
            target.uri == source.uri and
            target.user_id == source.user_id,
        where:
          source.tag_id == ^source_tag_id and
            source.aasm_state != "rejected" and
            target.aasm_state != "rejected",
        select: source.id

    multi
    |> Multi.delete_all(
      :delete_conflicting_artist_links,
      from(link in ArtistLink, where: link.id in subquery(conflicts))
    )
    |> Multi.update_all(
      :update_artist_links,
      where(ArtistLink, tag_id: ^source_tag_id),
      set: [tag_id: target_tag_id]
    )
  end

  @doc """
  Counts the number of artist links which are pending moderation action, or
  nil if the user is not permitted to moderate artist links.

  ## Examples

      iex> count_artist_links(normal_user)
      nil

      iex> count_artist_links(admin_user)
      0

  """
  @spec count_artist_links(User.t() | nil) :: non_neg_integer() | nil
  def count_artist_links(user) do
    if authorize(user, :index, ArtistLink) == :ok do
      ArtistLink
      |> where([ul], ul.aasm_state in ^["unverified", "link_verified"])
      |> Repo.aggregate(:count)
    else
      nil
    end
  end
end
