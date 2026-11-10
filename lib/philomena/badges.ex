defmodule Philomena.Badges do
  @moduledoc """
  Administration for badges and associated awards attached to user profiles.

  Performs artist badge awarding for verified artist links.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Multi
  alias Philomena.Attribution.Actor
  alias Philomena.Authorization
  alias Philomena.Badges.{Award, Badge, Uploader}
  alias Philomena.Loader
  alias Philomena.ModerationLogs
  alias Philomena.ModerationLogs.Paths
  alias Philomena.Repo
  alias Philomena.Users.User

  defp load_badge(actor, action, id) do
    Loader.fetch_and_authorize(Badge, actor, action, id)
  end

  @doc """
  Returns the paginated badges for the admin listing, on behalf of `actor`,
  ordered by title.

  ## Examples

      iex> list_badges(admin, pagination)
      {:ok, %Scrivener.Page{}}

      iex> list_badges(user, pagination)
      {:error, :unauthorized}

  """
  @spec list_badges(Actor.t(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t()} | {:error, :unauthorized}
  def list_badges(%Actor{} = actor, pagination) do
    with :ok <- authorize(actor, :index, Badge) do
      {:ok,
       Badge
       |> order_by(asc: :title)
       |> Repo.paginate(pagination)}
    end
  end

  @doc """
  Builds the changeset for creating a badge, on behalf of `actor`.

  ## Examples

      iex> new_badge(admin)
      {:ok, %Ecto.Changeset{}}

      iex> new_badge(user)
      {:error, :unauthorized}

  """
  @spec new_badge(Actor.t()) :: {:ok, Ecto.Changeset.t()} | Authorization.write_error()
  def new_badge(%Actor{} = actor) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :new, Badge) do
      {:ok, Badge.changeset(%Badge{})}
    end
  end

  @doc """
  Creates a badge on behalf of `actor`, running the SVG upload pipeline.

  On success a moderation log attributing the creation to `actor` is written.

  ## Examples

      iex> create_badge(admin, badge_params, upload)
      {:ok, %Badge{}}

      iex> create_badge(admin, invalid_params, upload)
      {:error, %Ecto.Changeset{}}

      iex> create_badge(user, badge_params, upload)
      {:error, :unauthorized}

  """
  @spec create_badge(Actor.t(), map(), PhilomenaMedia.Upload.t() | nil) ::
          {:ok, Badge.t()}
          | {:error, Authorization.write_error_reason() | Ecto.Changeset.t()}
  def create_badge(%Actor{} = actor, attrs, upload) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, Badge) do
      badge_changeset =
        %Badge{}
        |> Badge.changeset(attrs)
        |> Uploader.analyze_upload(upload)

      Multi.new()
      |> Multi.insert(:badge, badge_changeset)
      |> Uploader.put_persist_upload_and_unpersist_old(:badge)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{badge: badge} ->
          {"Admin.Badge:create", "/admin/badges", "Created badge '#{badge.title}'"}
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{badge: %Badge{} = badge}} ->
          {:ok, badge}

        {:error, :badge, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Loads the badge named by `id` for editing, on behalf of `actor`, pairing it
  with a changeset for editing it.

  ## Examples

      iex> edit_badge(admin, badge_id)
      {:ok, {%Badge{}, %Ecto.Changeset{}}}

      iex> edit_badge(admin, invalid_id)
      {:error, :not_found}

      iex> edit_badge(user, badge_id)
      {:error, :unauthorized}

  """
  @spec edit_badge(Actor.t(), Loader.integer_id()) ::
          {:ok, {Badge.t(), Ecto.Changeset.t()}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def edit_badge(%Actor{} = actor, id) do
    with :ok <- verify_not_banned(actor),
         {:ok, badge} <- load_badge(actor, :edit, id) do
      {:ok, {badge, Badge.changeset(badge)}}
    end
  end

  @doc """
  Updates the badge named by `id` without touching its image, on behalf of
  `actor`.

  On success a moderation log attributing the update to `actor` is written.

  ## Examples

      iex> update_badge(admin, badge_id, badge_params)
      {:ok, %Badge{}}

      iex> update_badge(admin, badge_id, invalid_params)
      {:error, %Ecto.Changeset{}}

      iex> update_badge(admin, invalid_id, badge_params)
      {:error, :not_found}

      iex> update_badge(user, badge_id, badge_params)
      {:error, :unauthorized}

  """
  @spec update_badge(Actor.t(), Loader.integer_id(), map()) ::
          {:ok, Badge.t()}
          | {:error, Authorization.write_error_reason() | :not_found | Ecto.Changeset.t()}
  def update_badge(%Actor{} = actor, id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, badge} <- load_badge(actor, :update, id) do
      badge_changeset = Badge.changeset(badge, attrs)

      Multi.new()
      |> Multi.update(:badge, badge_changeset)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{badge: badge} ->
          {"Admin.Badge:update", "/admin/badges", "Updated badge '#{badge.title}'"}
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{badge: %Badge{} = badge}} ->
          {:ok, badge}

        {:error, :badge, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Updates the image of the badge named by `id`, on behalf of `actor`, running
  the SVG upload pipeline.

  On success a moderation log attributing the update to `actor` is written.

  ## Examples

      iex> update_badge_image(admin, badge_id, upload)
      {:ok, %Badge{}}

      iex> update_badge_image(admin, badge_id, nil)
      {:error, %Ecto.Changeset{}}

      iex> update_badge_image(admin, invalid_id, upload)
      {:error, :not_found}

      iex> update_badge_image(user, badge_id, upload)
      {:error, :unauthorized}

  """
  @spec update_badge_image(Actor.t(), Loader.integer_id(), PhilomenaMedia.Upload.t() | nil) ::
          {:ok, Badge.t()}
          | {:error, Authorization.write_error_reason() | :not_found | Ecto.Changeset.t()}
  def update_badge_image(%Actor{} = actor, id, upload) do
    with :ok <- verify_write_access(actor),
         {:ok, badge} <- load_badge(actor, :update_image, id) do
      badge_changeset =
        badge
        |> Badge.changeset()
        |> Uploader.analyze_upload(upload)

      Multi.new()
      |> Multi.update(:badge, badge_changeset)
      |> Uploader.put_persist_upload_and_unpersist_old(:badge)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{badge: badge} ->
          {"Admin.Badge.Image:update", "/admin/badges", "Updated image of badge '#{badge.title}'"}
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{badge: %Badge{} = badge}} ->
          {:ok, badge}

        {:error, :badge, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Loads the badge named by `id` together with the users who hold it, on behalf
  of `actor`, paginated and ordered by name.

  ## Examples

      iex> list_badge_users(admin, badge_id, pagination)
      {:ok, {%Badge{}, %Scrivener.Page{}}}

      iex> list_badge_users(admin, invalid_id, pagination)
      {:error, :not_found}

      iex> list_badge_users(user, badge_id, pagination)
      {:error, :unauthorized}

  """
  @spec list_badge_users(Actor.t(), Loader.integer_id(), Repo.pagination_params()) ::
          {:ok, {Badge.t(), Scrivener.Page.t()}} | {:error, :unauthorized | :not_found}
  def list_badge_users(%Actor{} = actor, id, pagination) do
    with {:ok, badge} <- load_badge(actor, :show_users, id) do
      users =
        User
        |> join(:inner, [u], _ in assoc(u, :awards))
        |> where([_u, a], a.badge_id == ^badge.id)
        |> order_by([u, _a], asc: u.name)
        |> Repo.paginate(pagination)

      {:ok, {badge, users}}
    end
  end

  defp awardable_badges do
    Badge
    |> where(disable_award: false)
    |> order_by(asc: :title)
    |> Repo.all()
  end

  defp load_authorized_profile(%Actor{} = actor, action, slug) do
    User
    |> where(slug: ^slug)
    |> where([u], is_nil(u.deleted_at))
    |> Loader.one_and_authorize(actor, action)
  end

  defp load_scoped_award(%Actor{} = actor, action, slug, id) do
    with {:ok, user} <- load_authorized_profile(actor, :show, slug) do
      Award
      |> where(user_id: ^user.id)
      |> preload([:user, :badge])
      |> Loader.fetch_and_authorize(actor, action, id)
    end
  end

  @doc """
  Loads the user named by the profile `slug` for creating an award, on behalf
  of `actor`.

  ## Examples

      iex> new_award(admin, user.slug)
      {:ok, {%User{}, %Ecto.Changeset{}, [%Badge{}, ...]}}

      iex> new_award(admin, invalid_slug)
      {:error, :not_found}

      iex> new_award(user, user.slug)
      {:error, :unauthorized}

  """
  @spec new_award(Actor.t(), String.t()) ::
          {:ok, {User.t(), Ecto.Changeset.t(), [Badge.t()]}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def new_award(%Actor{} = actor, slug) do
    with :ok <- verify_not_banned(actor),
         {:ok, user} <- load_authorized_profile(actor, :show, slug),
         :ok <- authorize(actor, :new, Award) do
      {:ok, {user, Award.changeset(%Award{}), awardable_badges()}}
    end
  end

  @doc """
  Awards a badge to the user named by the profile `slug`, on behalf of `actor`,
  from `attrs`.

  On success a moderation log attributing the award to `actor` is written.
  Duplicate grants are allowed and create separate award records.

  ## Examples

      iex> create_award(admin, user.slug, award_params)
      {:ok, {%User{}, %Award{}}}

      iex> create_award(admin, user.slug, invalid_params)
      {:error, {%User{}, %Ecto.Changeset{}, [%Badge{}, ...]}}

      iex> create_award(admin, invalid_slug, award_params)
      {:error, :not_found}

      iex> create_award(user, user.slug, award_params)
      {:error, :unauthorized}

  """
  @spec create_award(Actor.t(), String.t(), map()) ::
          {:ok, {User.t(), Award.t()}}
          | {:error, {User.t(), Ecto.Changeset.t(), [Badge.t()]}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def create_award(%Actor{user: creator} = actor, slug, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_authorized_profile(actor, :show, slug),
         :ok <- authorize(actor, :create, Award) do
      award_changeset =
        %Award{awarded_by_id: creator.id, user_id: user.id}
        |> Award.changeset(attrs)

      Multi.new()
      |> Multi.insert(:award, award_changeset)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{award: award} ->
        award = Repo.preload(award, :badge)

        {
          "Profile.Award:create",
          Paths.profile_path(user),
          "Awarded badge '#{award.badge.title}' to #{user.name}"
        }
      end)
      |> Multi.transact()
      |> case do
        {:ok, %{award: %Award{} = award}} ->
          {:ok, {user, award}}

        {:error, :award, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, {user, changeset, awardable_badges()}}
      end
    end
  end

  @doc """
  Loads the award named by `id` under the profile `slug` for editing, on behalf
  of `actor`.

  ## Examples

      iex> edit_award(admin, user.slug, award_id)
      {:ok, {%User{}, %Award{}, %Ecto.Changeset{}, [%Badge{}, ...]}}

      iex> edit_award(admin, invalid_slug, award_id)
      {:error, :not_found}

      iex> edit_award(admin, user.slug, invalid_id)
      {:error, :not_found}

      iex> edit_award(user, user.slug, award_id)
      {:error, :unauthorized}

  """
  @spec edit_award(Actor.t(), String.t(), Loader.integer_id()) ::
          {:ok, {User.t(), Award.t(), Ecto.Changeset.t(), [Badge.t()]}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def edit_award(%Actor{} = actor, slug, id) do
    with :ok <- verify_not_banned(actor),
         {:ok, award} <- load_scoped_award(actor, :edit, slug, id) do
      {:ok, {award.user, award, Award.changeset(award), awardable_badges()}}
    end
  end

  @doc """
  Updates the award named by `id` under the profile `slug`, on behalf of
  `actor`, from `attrs`.

  On success a moderation log attributing the update to `actor` is written.

  ## Examples

      iex> update_award(admin, user.slug, award_id, award_params)
      {:ok, {%User{}, %Award{}}}

      iex> update_award(admin, user.slug, award_id, invalid_params)
      {:error, {%User{}, %Award{}, %Ecto.Changeset{}, [%Badge{}, ...]}}

      iex> update_award(admin, invalid_slug, award_id, award_params)
      {:error, :not_found}

      iex> update_award(admin, user.slug, invalid_id, award_params)
      {:error, :not_found}

      iex> update_award(user, user.slug, award_id, award_params)
      {:error, :unauthorized}

  """
  @spec update_award(Actor.t(), String.t(), Loader.integer_id(), map()) ::
          {:ok, {User.t(), Award.t()}}
          | {:error, {User.t(), Award.t(), Ecto.Changeset.t(), [Badge.t()]}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def update_award(%Actor{} = actor, slug, id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, award} <- load_scoped_award(actor, :update, slug, id) do
      award_changeset = Award.changeset(award, attrs)

      Multi.new()
      |> Multi.update(:award, award_changeset)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{award: award} ->
          award = Repo.preload(award, :badge, force: true)

          {
            "Profile.Award:update",
            Paths.profile_path(award.user),
            "Updated award of badge '#{award.badge.title}' on #{award.user.name}"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{award: %Award{} = award}} ->
          {:ok, {award.user, award}}

        {:error, :award, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, {award.user, award, changeset, awardable_badges()}}
      end
    end
  end

  @doc """
  Revokes the award named by `id` under the profile `slug`, on behalf of
  `actor`.

  On success a moderation log attributing the removal to `actor` is written.

  ## Examples

      iex> delete_award(admin, user.slug, award_id)
      {:ok, {%User{}, %Award{}}}

      iex> delete_award(admin, invalid_slug, award_id)
      {:error, :not_found}

      iex> delete_award(admin, user.slug, invalid_id)
      {:error, :not_found}

      iex> delete_award(user, user.slug, award_id)
      {:error, :unauthorized}

  """
  @spec delete_award(Actor.t(), String.t(), Loader.integer_id()) ::
          {:ok, {User.t(), Award.t()}}
          | {:error, Authorization.write_error_reason() | :not_found | Ecto.Changeset.t()}
  def delete_award(%Actor{} = actor, slug, id) do
    with :ok <- verify_write_access(actor),
         {:ok, award} <- load_scoped_award(actor, :delete, slug, id) do
      Multi.new()
      |> Multi.delete(:award, award)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{award: award} ->
          {
            "Profile.Award:delete",
            Paths.profile_path(award.user),
            "Removed badge '#{award.badge.title}' from #{award.user.name}"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{award: %Award{} = award}} ->
          {:ok, {award.user, award}}

        {:error, :award, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Adds the automatic "Artist" badge award for a verified artist link to `multi`.

  The underlying award operation returns `{:ok, award}`, `{:ok, nil}`, or
  `{:error, changeset}` as the result of the `Multi.run/3` callback.
  Existing awards and a missing Artist badge are intentional no-ops.
  """
  @spec put_award_artist_badge(
          multi :: Multi.t(),
          target_user :: User.t(),
          verifying_user :: User.t()
        ) :: Multi.t()
  def put_award_artist_badge(%Multi{} = multi, %User{} = target_user, %User{} = verifying_user) do
    Multi.run(multi, :award, fn repo, _changes ->
      with %Badge{} = badge <- repo.get_by(Badge, title: "Artist"),
           nil <- repo.get_by(Award, badge_id: badge.id, user_id: target_user.id) do
        %Award{awarded_by_id: verifying_user.id, user_id: target_user.id}
        |> Award.changeset(%{badge_id: badge.id})
        |> repo.insert()
      else
        _ -> {:ok, nil}
      end
    end)
  end
end
