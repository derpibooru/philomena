defmodule Philomena.Users do
  @moduledoc """
  Authentication, registration, profiles, account settings, and staff user
  management.

  Authentication token services deliberately have no actor because the
  token is the credential. Loaded record entry points are limited to explicit
  worker, indexing, filter, and erasure collaboration services.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Multi
  alias Philomena.Repo
  alias Philomena.Tags

  alias Philomena.Attribution.Actor
  alias PhilomenaQuery.Search
  alias Philomena.Users

  alias Philomena.Users.{
    AdminUserForm,
    AliasMatches,
    QueryBuilder,
    QueryForm,
    RoleForm,
    Settings,
    Uploader,
    User,
    UserNotifier,
    UserToken
  }

  alias Philomena.{Forums, Forums.Forum}
  alias Philomena.Bans
  alias Philomena.Topics
  alias Philomena.Roles.Role
  alias Philomena.UserIps.UserIp
  alias Philomena.UserFingerprints.UserFingerprint
  alias Philomena.UserNameChanges
  alias Philomena.UserNameChanges.UserNameChange
  alias Philomena.Images
  alias Philomena.Comments
  alias Philomena.Posts
  alias Philomena.Galleries
  alias Philomena.Reports
  alias Philomena.Filters
  alias Philomena.TagChanges
  alias Philomena.Filters.Filter
  alias Philomena.ModerationLogs
  alias Philomena.ModerationLogs.Paths
  alias Philomena.IndexWorker
  alias Philomena.Loader
  alias Philomena.UserEraseWorker
  alias Philomena.UserRenameWorker
  alias Philomena.UserUnvoteWorker
  alias Philomena.UserWipeWorker

  ## Shared locators

  defp load_user_by_slug(actor, action, slug, preloads \\ [])

  defp load_user_by_slug(actor, action, slug, preloads) when is_binary(slug) do
    User
    |> where([user], user.slug == ^slug)
    |> preload(^preloads)
    |> Loader.one_and_authorize(actor, action)
  end

  defp load_user_by_slug(_actor, _action, _slug, _preloads), do: {:error, :not_found}

  ## Authentication and token transaction composition

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Multi.new()
    |> Multi.update(:user, changeset)
    |> Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  defp unlock_user_multi(user) do
    changeset = User.unlock_changeset(user)

    Multi.new()
    |> Multi.update(:user, changeset)
    |> Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["unlock"]))
  end

  defp confirm_user_multi(user) do
    Multi.new()
    |> Multi.update(:user, User.confirm_changeset(user))
    |> Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  defp verify_user_for_authentication(user) do
    if is_nil(user.confirmed_at) do
      {:error, :unconfirmed}
    else
      {:ok, user}
    end
  end

  defp verify_user_for_password_authentication(user, password_compromised?) do
    if password_compromised? do
      # Immediately delete user sessions to notify the user that a reset is needed.
      delete_user_sessions(user)

      {:error, :password_compromised}
    else
      verify_user_for_authentication(user)
    end
  end

  ## Settings and role assignment

  defp admin_user_form(changeset) do
    %AdminUserForm{
      changeset: changeset,
      roles: Repo.all(Role)
    }
  end

  defp fetch_roles(role_ids) do
    Role
    |> where([role], role.id in ^role_ids)
    |> Repo.all()
    |> case do
      roles when length(roles) == length(role_ids) ->
        {:ok, roles}

      _roles ->
        {:error, :not_found}
    end
  end

  defp update_user_changeset(user, attrs) do
    with {:ok, role_ids} <- RoleForm.fetch_role_ids(attrs),
         {:ok, roles} <- fetch_roles(role_ids) do
      User.update_changeset(user, attrs, roles)
    else
      {:error, :not_found} ->
        User.role_error_changeset(user)
    end
  end

  defp setup_roles(nil), do: nil

  defp setup_roles(user) do
    role_map =
      user.roles
      |> Enum.group_by(& &1.resource_type, & &1.name)
      |> Map.new(fn {type, names} -> {type, Map.new(names, &{&1, []})} end)

    %{user | role_map: role_map}
  end

  defp load_with_roles(query) do
    query |> Repo.one() |> load_user_with_roles()
  end

  defp load_user_with_roles(nil), do: nil

  defp load_user_with_roles(user) do
    user
    |> Repo.preload([:roles, :current_filter, :settings])
    |> setup_roles()
  end

  ## Avatar persistence

  defp clear_avatar(%User{} = user) do
    changeset = User.remove_avatar_changeset(user)

    Multi.new()
    |> Multi.update(:user, changeset)
    |> Uploader.put_unpersist_old_upload(:user)
    |> put_reindex_user()
    |> Multi.transact()
    |> case do
      {:ok, %{user: %User{} = user}} ->
        {:ok, user}

      {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  # Transaction composition

  defp user_lock_query(%User{id: id}) do
    User
    |> where(id: ^id)
    |> preload([:roles, :settings])
  end

  defp put_unsubscribe_restricted_actors(multi, step) do
    Multi.run(multi, step, fn repo, %{user: user} ->
      forum_ids =
        Forum
        |> order_by(asc: :name)
        |> repo.all()
        |> Enum.reject(&(authorize(user, :show, &1) == :ok))
        |> Enum.map(& &1.id)

      {_count, nil} =
        Forums.Subscription
        |> where(
          [subscription],
          subscription.user_id == ^user.id and subscription.forum_id in ^forum_ids
        )
        |> repo.delete_all()

      {_count, nil} =
        Topics.Subscription
        |> join(:inner, [subscription], _ in assoc(subscription, :topic))
        |> where(
          [subscription, topic],
          subscription.user_id == ^user.id and topic.forum_id in ^forum_ids
        )
        |> repo.delete_all()

      {:ok, nil}
    end)
  end

  ## Post-commit hooks

  defp put_reindex_user(multi) do
    Multi.on_commit(multi, fn %{user: user} -> reindex_user(user) end)
  end

  defp put_wipe_user_votes_job(multi, [{:upvotes_and_faves?, upvotes_and_faves?}]) do
    Multi.on_commit(multi, fn %{user: user} ->
      Exq.enqueue(Exq, "indexing", UserUnvoteWorker, [user.id, upvotes_and_faves?])
    end)
  end

  defp put_wipe_user_job(multi) do
    Multi.on_commit(multi, fn %{user: user} ->
      Exq.enqueue(Exq, "indexing", UserWipeWorker, [user.id])
    end)
  end

  defp put_rename_user_job(multi, [{:old_name, old_name}]) do
    Multi.on_commit(multi, fn %{user: user} ->
      Exq.enqueue(Exq, "indexing", UserRenameWorker, [old_name, user.name])
    end)
  end

  defp put_erase_user_job(multi, %Actor{} = actor) do
    Multi.on_commit(multi, fn %{user: user} ->
      Exq.enqueue(Exq, "indexing", UserEraseWorker, [user.id, actor.user.id])
    end)
  end

  ## Public reads

  @doc group: "Public reads"
  @doc """
  Loads the active profile named by integer `id` for `actor`, with public links
  and badge awards preloaded.

  Malformed, missing, and deactivated IDs are consistently not-found. A real
  active user the actor may not show is unauthorized.

  ## Examples

      iex> show_profile(actor, "1")
      {:ok, %User{}}

      iex> show_profile(actor, "not-an-id")
      {:error, :not_found}

  """
  @spec show_profile(Actor.t(), Loader.integer_id()) ::
          {:ok, User.t()} | {:error, :unauthorized | :not_found}
  def show_profile(%Actor{} = actor, id) do
    User
    |> where([user], is_nil(user.deleted_at))
    |> Loader.fetch_and_authorize(actor, :show, id, public_links: :tag, awards: :badge)
  end

  @doc group: "Public reads"
  @doc """
  Loads the visible profile named by `slug` for `actor`.

  Missing profiles are not found. Deactivated profiles are not found unless the
  actor may show user details. A real profile that the actor may not show is
  unauthorized.

  ## Examples

      iex> load_profile(actor, "somebody")
      {:ok, %User{}}

      iex> load_profile(actor, "missing")
      {:error, :not_found}

  """
  @spec load_profile(Actor.t(), String.t(), list()) ::
          {:ok, User.t()} | {:error, :unauthorized | :not_found}
  def load_profile(%Actor{} = actor, slug, preloads \\ []) do
    query = where(User, [user], user.slug == ^slug)

    query =
      if authorize(actor, :show_details, %User{}) == :ok,
        do: query,
        else: where(query, [user], is_nil(user.deleted_at))

    query
    |> preload(^preloads)
    |> Loader.one_and_authorize(actor, :show)
  end

  @doc group: "Public reads"
  @doc """
  Loads an active user by exact name for an actor-scoped cross-context lookup.

  Conversations use this locator when resolving a recipient. Missing,
  malformed, and deactivated recipients are always not found.

  ## Examples

      iex> load_active_user_by_name(actor, "Somebody")
      {:ok, %User{}}

      iex> load_active_user_by_name(actor, "missing")
      {:error, :not_found}

  """
  @spec load_active_user_by_name(Actor.t(), term()) ::
          {:ok, User.t()} | {:error, :unauthorized | :not_found}
  def load_active_user_by_name(%Actor{} = actor, name) when is_binary(name) do
    User
    |> where([user], user.name == ^name and is_nil(user.deleted_at))
    |> Loader.one_and_authorize(actor, :show)
  end

  def load_active_user_by_name(%Actor{}, _name), do: {:error, :not_found}

  @doc group: "Public reads"
  @doc """
  Loads a visible profile by slug as a report target on behalf of `actor`,
  following `load_profile/3`.

  ## Examples

      iex> load_report_target(actor, "somebody")
      {:ok, %User{}}
  """
  @spec load_report_target(Actor.t(), String.t()) ::
          {:ok, User.t()} | {:error, :unauthorized | :not_found}
  def load_report_target(%Actor{} = actor, slug) do
    with {:ok, user} <- load_profile(actor, slug) do
      {:ok, Repo.preload(user, public_links: :tag, awards: :badge)}
    end
  end

  @doc group: "Public reads"
  @doc """
  Preloads a user's awards and their badges.

  Returns `nil` when given `nil`.

  ## Examples

      iex> preload_preview_awards(user)
      %User{awards: [%Award{badge: %Badge{}}]}

      iex> preload_preview_awards(nil)
      nil

  """
  @spec preload_preview_awards(User.t() | nil) :: User.t() | nil
  def preload_preview_awards(user), do: Repo.preload(user, awards: :badge)

  @doc group: "Public reads"
  @doc """
  Returns the site staff grouped into categories, as a map keyed by semantic
  category names.

  Staff are the users whose role is `"admin"`, `"moderator"`, or `"assistant"`,
  ordered by name.

  ## Examples

      iex> staff_categories()
      %{administrators: [%User{}], developers: [], ...}

  """
  @spec staff_categories() :: %{atom() => [User.t()]}
  def staff_categories do
    staff =
      User
      |> where([u], u.role != "user")
      |> order_by(asc: :name)
      |> Repo.all()

    {admins, staff} =
      Enum.split_with(staff, &(&1.role == "admin" and not &1.hide_default_role))

    {developers, staff} =
      Enum.split_with(staff, &(&1.secondary_role in ["Site Developer", "Devops"]))

    {public_relations, staff} =
      Enum.split_with(staff, &(&1.secondary_role == "Public Relations"))

    {others, staff} = Enum.split_with(staff, & &1.hide_default_role)

    %{
      administrators: admins,
      moderators: Enum.filter(staff, &(&1.role == "moderator")),
      assistants: Enum.filter(staff, &(&1.role == "assistant")),
      developers: developers,
      public_relations: public_relations,
      others: others
    }
  end

  ## Authentication

  @doc group: "Authentication"
  @doc """
  Checks whether a password has appeared in a known data breach.

  The check is disabled when the `:pwned_passwords` application setting is
  `false`. Network failures are treated as a password that was not found.

  ## Examples

      iex> password_compromised?(:crypto.strong_rand_bytes(16))
      false

      iex> password_compromised?("password")
      true

  """
  # The Pwned Passwords range API is keyed by SHA-1 prefixes.
  # sobelow_skip ["Crypto.WeakHash"]
  @spec password_compromised?(String.t()) :: boolean()
  def password_compromised?(password) when is_binary(password) do
    if Application.get_env(:philomena, :pwned_passwords) == false do
      false
    else
      <<prefix::binary-size(5), rest::binary>> =
        :sha
        |> :crypto.hash(password)
        |> Base.encode16()

      case PhilomenaProxy.Http.get("https://api.pwnedpasswords.com/range/#{prefix}") do
        {:ok, %{body: body, status: 200}} ->
          String.contains?(body, rest <> ":")

        _ ->
          false
      end
    end
  end

  @doc group: "Authentication"
  @doc """
  Deletes every active session, including incomplete TOTP login sessions, for a user.

  ## Example

      iex> delete_user_sessions(user)
      :ok

  """
  @spec delete_user_sessions(User.t()) :: :ok
  def delete_user_sessions(user) do
    Repo.delete_all(UserToken.user_and_contexts_query(user, ["session", "totp"]))
    :ok
  end

  @doc group: "Authentication"
  @doc """
  Gets a user by API token.

  ## Examples

      iex> get_user_by_authentication_token("5Ow89k7nW24E0K34d3zX")
      %User{}

      iex> get_user_by_authentication_token("invalid")
      nil

  """
  @spec get_user_by_authentication_token(String.t()) :: User.t() | nil
  def get_user_by_authentication_token(token) when is_binary(token) do
    User
    |> Repo.get_by(authentication_token: token)
    |> Repo.preload(:settings)
  end

  @doc group: "Authentication"
  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc group: "Authentication"
  @doc """
  Gets a user by email and password.

  Users which are locked, unconfirmed, or whose password is valid and matches
  a password found in a public data breach return an error.

  ## Examples

      iex> fetch_user_by_email_and_password("foo@example.com", "correct_password", &unlock_url/1)
      {:ok, %User{}}

      iex> fetch_user_by_email_and_password("foo@example.com", "invalid_password", &unlock_url/1)
      {:error, :not_found}

  """
  @spec fetch_user_by_email_and_password(String.t(), String.t(), (String.t() -> String.t())) ::
          {:ok, User.t()}
          | {:error, :unconfirmed | :password_compromised | :not_found}
  def fetch_user_by_email_and_password(email, password, unlock_url_fun)
      when is_binary(email) and is_binary(password) do
    user_query =
      from user in User,
        where: user.email == ^email,
        where: is_nil(user.locked_at)

    Multi.new()
    |> Multi.lock_one(:locked_user, user_query)
    |> Multi.run(:valid_password?, fn _repo, %{locked_user: user} ->
      {:ok, User.valid_password?(user, password)}
    end)
    |> Multi.update(:user, fn %{valid_password?: valid_password?, locked_user: user} ->
      if valid_password? do
        User.successful_attempt_changeset(user)
      else
        User.failed_attempt_changeset(user)
      end
    end)
    |> put_reindex_user()
    |> Multi.transact()
    |> case do
      {:ok, %{valid_password?: true, user: %User{} = user}} ->
        verify_user_for_password_authentication(user, password_compromised?(password))

      {:ok, %{valid_password?: false, user: %User{} = user}} ->
        if user.locked_at do
          deliver_user_unlock_instructions(user, unlock_url_fun)
        end

        {:error, :not_found}

      {:error, :locked_user, :not_found, _changes} ->
        {:error, :not_found}
    end
  end

  ## User registration

  @doc group: "Registration"
  @doc """
  Registers a user on behalf of actor.

  ## Examples

      iex> create_registration(actor, %{field: value})
      {:ok, %User{}}

      iex> create_registration(actor, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

      iex> create_registration(banned_actor, %{field: value})
      {:error, :ban}

  """
  @spec create_registration(Actor.t(), map()) ::
          {:ok, User.t()}
          | {:error, :ban | :unauthorized | Ecto.Changeset.t()}
  def create_registration(%Actor{} = actor, params) do
    with :ok <- verify_write_access(actor) do
      changeset = User.registration_changeset(%User{}, &password_compromised?/1, params)

      Multi.new()
      |> Multi.insert(:user, changeset)
      |> put_reindex_user()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Registration"
  @doc """
  Returns an `%Ecto.Changeset{}` for tracking registration changes on behalf
  of actor.

  ## Examples

      iex> new_registration(actor, user)
      {:ok, %Ecto.Changeset{data: %User{}}}

      iex> new_registration(banned_actor, user)
      {:error, :ban}

  """
  @spec new_registration(Actor.t(), User.t(), map()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban}
  def new_registration(%Actor{} = actor, %User{} = user, attrs \\ %{}) do
    with :ok <- verify_not_banned(actor) do
      {:ok, User.registration_changeset(user, &password_compromised?/1, attrs)}
    end
  end

  ## Settings

  @doc group: "Account settings"
  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  @spec change_user_email(User.t(), map()) :: Ecto.Changeset.t()
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs)
  end

  @doc group: "Account settings"
  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> create_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> create_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_email(User.t(), String.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc group: "Account settings"
  @doc """
  Updates the user email in token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.

  ## Examples

      iex> show_email(user, token)
      :ok

      iex> show_email(user, "invalid")
      :error

  """
  @spec show_email(User.t(), String.t()) :: :ok | :error
  def show_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _changes} <-
           user
           |> user_email_multi(email, context)
           |> put_reindex_user()
           |> Multi.transact() do
      :ok
    else
      _ -> :error
    end
  end

  @doc group: "Account settings"
  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_update_email_instructions(user, current_email, &url(~p"/registrations/email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  @spec deliver_update_email_instructions(
          User.t(),
          String.t(),
          (String.t() -> String.t())
        ) :: term()
  def deliver_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc group: "Account settings"
  @doc """
  Unlocks the user by the given token.

  If the token matches, the user is marked as unlocked
  and the token is deleted.

  ## Examples

      iex> show_unlock(token)
      {:ok, %User{}}

      iex> show_unlock("invalid")
      :error

  """
  @spec show_unlock(String.t()) :: {:ok, User.t()} | :error
  def show_unlock(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "unlock"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: %User{} = user}} <-
           user
           |> unlock_user_multi()
           |> put_reindex_user()
           |> Multi.transact() do
      {:ok, user}
    else
      _ -> :error
    end
  end

  @doc group: "Account settings"
  @doc ~S"""
  Delivers the unlock instructions to the given user.

  ## Examples

      iex> deliver_user_unlock_instructions(user, &url(~p"/unlocks/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  @spec deliver_user_unlock_instructions(User.t(), (String.t() -> String.t())) :: term()
  def deliver_user_unlock_instructions(%User{} = user, unlock_url_fun)
      when is_function(unlock_url_fun, 1) do
    if is_nil(user.locked_at) do
      {:error, :not_locked}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "unlock")
      Repo.insert!(user_token)
      UserNotifier.deliver_unlock_instructions(user, unlock_url_fun.(encoded_token))
    end
  end

  @doc group: "Account settings"
  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> edit_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  @spec edit_password(User.t(), map()) :: Ecto.Changeset.t()
  def edit_password(user, attrs \\ %{}) do
    User.password_changeset(user, &password_compromised?/1, attrs)
  end

  @doc group: "Account settings"
  @doc """
  Updates the user password.

  ## Examples

      iex> update_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_password(User.t(), String.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(&password_compromised?/1, attrs)
      |> User.validate_current_password(password)

    Multi.new()
    |> Multi.update(:user, changeset)
    |> Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> put_reindex_user()
    |> Multi.transact()
    |> case do
      {:ok, %{user: %User{} = user}} ->
        {:ok, user}

      {:error, :user, %Ecto.Changeset{} = changeset, _} ->
        {:error, changeset}
    end
  end

  ## Two-factor authentication

  @doc group: "Two-factor authentication"
  @doc """
  Generates and stores a fresh TOTP secret for the user's account.

  The secret must exist before two-factor authentication can be confirmed. Does
  not reindex.

  ## Examples

      iex> edit_totp(user)
      {:ok, %User{}}

  """
  @spec edit_totp(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def edit_totp(%User{} = user) do
    user
    |> User.create_totp_secret_changeset()
    |> Repo.update()
  end

  @doc group: "Two-factor authentication"
  @doc """
  Enables or disables two-factor authentication for the user's account.

  Accepts `params` carrying the current password and second-factor token. When
  TOTP is off and both checks pass, it is enabled and a fresh set of backup
  codes is generated; when TOTP is on it is disabled. On success the user is
  reindexed.

  Returns `{:ok, user, backup_codes}` - the plaintext backup codes cannot be
  retrieved afterward and are always freshly generated, even when disabling -
  or `{:error, %Ecto.Changeset{}}` when the password or token is rejected.

  ## Examples

      iex> update_totp(user, %{"user" => %{"current_password" => "...", "twofactor_token" => "..."}})
      {:ok, %User{}, ["a1b2c3d4e5f6", ...]}

  """
  @spec update_totp(User.t(), map()) ::
          {:ok, User.t(), [String.t()]} | {:error, Ecto.Changeset.t()}
  def update_totp(%User{} = user, params) do
    backup_codes = User.random_backup_codes()

    Multi.new()
    |> Multi.update(:user, User.totp_changeset(user, params, backup_codes))
    |> put_reindex_user()
    |> Multi.transact()
    |> case do
      {:ok, %{user: %User{} = user}} ->
        {:ok, user, backup_codes}

      {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc group: "Two-factor authentication"
  @doc """
  Checks if a TOTP token is valid for a given user.

  Returns false if no user is provided.

  ## Examples

      iex> user_totp_token_valid?(user, "123456")
      true

      iex> user_totp_token_valid?(nil, "123456")
      false

  """
  @spec user_totp_token_valid?(User.t() | nil, binary()) :: boolean()
  def user_totp_token_valid?(nil, _token) do
    false
  end

  def user_totp_token_valid?(user, token) do
    {:ok, query} = UserToken.verify_totp_token_query(user, token)
    Repo.exists?(query)
  end

  @doc group: "Two-factor authentication"
  @doc """
  Returns the TOTP form changeset for a loaded user.

  ## Examples

      iex> totp_changeset(user)
      %Ecto.Changeset{}

  """
  @spec totp_changeset(User.t()) :: Ecto.Changeset.t()
  def totp_changeset(%User{} = user), do: User.changeset(user)

  @doc group: "Two-factor authentication"
  @doc """
  Generates a TOTP token.

  ## Examples

      iex> generate_user_totp_token(user)
      "signed-token"

  """
  @spec generate_user_totp_token(User.t()) :: binary()
  def generate_user_totp_token(user) do
    {token, user_token} = UserToken.build_totp_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc group: "Two-factor authentication"
  @doc """
  Consumes a second-factor token for the given user during sign-in.

  Accepts the `params` (with the `"user"` / `"twofactor_token"`
  keys), validating the token against the user's TOTP secret or, failing that,
  remaining backup codes. A matching TOTP code records the consumed timestep;
  a matching backup code removes it from the list.

  Returns `{:ok, user}` when the token is accepted, or
  `{:error, %Ecto.Changeset{}}` when it is not.

  ## Examples

      iex> create_session_totp(user, %{"user" => %{"twofactor_token" => "123456"}})
      {:ok, %User{}}

  """
  @spec create_session_totp(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_session_totp(%User{} = user, params) do
    user
    |> User.consume_totp_token_changeset(params)
    |> Repo.update()
  end

  @doc group: "Two-factor authentication"
  @doc """
  Deletes the signed token with the given context.

  ## Examples

      iex> delete_totp_token(token)
      :ok

  """
  @spec delete_totp_token(binary()) :: :ok
  def delete_totp_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "totp"))
    :ok
  end

  ## Session

  @doc group: "Session"
  @doc """
  Generates a session token.

  ## Examples

      iex> generate_user_session_token(user)
      "signed-token"

  """
  @spec generate_user_session_token(User.t()) :: binary()
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc group: "Session"
  @doc """
  Gets the user with the given signed token.

  ## Examples

      iex> get_user_by_session_token(token)
      %User{}

      iex> get_user_by_session_token("invalid")
      nil

  """
  @spec get_user_by_session_token(binary()) :: User.t() | nil
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    load_with_roles(query)
  end

  @doc group: "Session"
  @doc """
  Gets the user with the given signed token and the token's creation time.

  The timestamp is used by the web authentication plug to periodically
  replace active session tokens.
  """
  @spec get_user_by_session_token_with_timestamp(binary()) ::
          {User.t(), DateTime.t()} | nil
  def get_user_by_session_token_with_timestamp(token) do
    {:ok, query} = UserToken.verify_session_token_query_with_timestamp(token)

    case Repo.one(query) do
      {user, token_inserted_at} ->
        {load_user_with_roles(user), token_inserted_at}

      nil ->
        nil
    end
  end

  @doc group: "Session"
  @doc """
  Deletes the signed token with the given context.

  ## Examples

      iex> delete_session_token(token)
      :ok

  """
  @spec delete_session_token(binary()) :: :ok
  def delete_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc group: "Confirmation"
  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/confirmations/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/confirmations/#{&1}"))
      {:error, :already_confirmed}

  """
  @spec deliver_user_confirmation_instructions(User.t(), (String.t() -> String.t())) :: term()
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc group: "Confirmation"
  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.

  ## Examples

      iex> update_confirmation(token)
      {:ok, %User{}}

      iex> update_confirmation("invalid")
      :error

  """
  @spec update_confirmation(String.t()) :: {:ok, User.t()} | :error
  def update_confirmation(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: %User{} = user}} <-
           user
           |> confirm_user_multi()
           |> put_reindex_user()
           |> Multi.transact() do
      {:ok, user}
    else
      _ -> :error
    end
  end

  ## Reset password

  @doc group: "Password reset"
  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/passwords/#{&1}/edit"))
      {:ok, %{to: ..., body: ...}}

  """
  @spec deliver_user_reset_password_instructions(User.t(), (String.t() -> String.t())) :: term()
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc group: "Password reset"
  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  @spec get_user_by_reset_password_token(String.t()) :: User.t() | nil
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc group: "Password reset"
  @doc """
  Resets the user password.

  ## Examples

      iex> update_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> update_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_password(User.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_password(user, attrs) do
    Multi.new()
    |> Multi.update(:user, User.password_changeset(user, &password_compromised?/1, attrs))
    |> Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> put_reindex_user()
    |> Multi.transact()
    |> case do
      {:ok, %{user: %User{} = user}} ->
        {:ok, user}

      {:error, :user, %Ecto.Changeset{} = changeset, _changeset} ->
        {:error, changeset}
    end
  end

  @doc group: "Account activation"
  @doc ~S"""
  Delivers the reactivate account email to the given user.

  ## Examples

      iex> deliver_user_reactivation_instructions(user, &url(~p"/reactivations/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  @spec deliver_user_reactivation_instructions(User.t(), (String.t() -> String.t())) :: term()
  def deliver_user_reactivation_instructions(%User{} = user, reactivation_url_fun)
      when is_function(reactivation_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reactivate")
    Repo.insert!(user_token)
    UserNotifier.deliver_reactivation_instructions(user, reactivation_url_fun.(encoded_token))
  end

  @doc group: "Account activation"
  @doc """
  Reactivates an account by one-time email token.

  Invalid, expired, and already consumed tokens all return `:error` without
  revealing whether an account exists.

  ## Examples

      iex> create_reactivation(token)
      {:ok, %User{}}

      iex> create_reactivation("invalid")
      :error

  """
  @spec create_reactivation(String.t()) :: {:ok, User.t()} | :error
  def create_reactivation(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reactivate"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: %User{} = user}} <-
           Multi.transact(
             Multi.new()
             |> Multi.update(:user, User.reactivate_changeset(user))
             |> Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["reactivate"]))
             |> put_reindex_user()
           ) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  @doc group: "Account activation"
  @doc """
  Deactivates the acting user's own account and sends a reactivation token.

  The database change commits before token delivery and indexing are queued.

  ## Examples

      iex> delete_deactivation(actor, &reactivation_url/1)
      {:ok, %User{}}

      iex> delete_deactivation(banned_actor, &reactivation_url/1)
      {:error, :ban}

  """
  @spec delete_deactivation(Actor.t(), (String.t() -> String.t())) ::
          {:ok, User.t()} | {:error, :ban | :unauthorized | Ecto.Changeset.t()}
  def delete_deactivation(%Actor{user: %User{} = user} = actor, reactivation_url_fun) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :deactivate_account, user) do
      Multi.new()
      |> Multi.lock_one(:locked_user, user_lock_query(user))
      |> Multi.update(:user, fn %{locked_user: user} ->
        User.deactivate_changeset(user, user)
      end)
      |> put_reindex_user()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          deliver_user_reactivation_instructions(user, reactivation_url_fun)

          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Settings"
  @doc """
  Returns the general settings changeset for a loaded user.

  ## Examples

      iex> settings_changeset(user)
      %Ecto.Changeset{}

  """
  @spec settings_changeset(User.t()) :: Ecto.Changeset.t()
  def settings_changeset(%User{} = user), do: User.changeset(user)

  @doc group: "Settings"
  @doc """
  Returns the filter-selection changeset for a loaded user.

  ## Examples

      iex> filter_selection_changeset(user)
      %Ecto.Changeset{}

  """
  @spec filter_selection_changeset(User.t()) :: Ecto.Changeset.t()
  def filter_selection_changeset(%User{} = user), do: User.changeset(user)

  @doc group: "Settings"
  @doc """
  Returns an `%Ecto.Changeset{}` for changing a user's spoiler type.

  ## Examples

      iex> spoiler_type_changeset(user)
      %Ecto.Changeset{data: %Settings{}}

  """
  @spec spoiler_type_changeset(User.t()) :: Ecto.Changeset.t()
  def spoiler_type_changeset(%User{} = user) do
    Settings.spoiler_type_changeset(user.settings, %{})
  end

  @doc group: "Settings"
  @doc """
  Updates a user's spoiler type settings.

  This personal preference update is deliberately exempt from
  `verify_write_access/1`, but the actor must be authorized to update their
  own settings.

  ## Examples

      iex> update_spoiler_type(actor, %{spoiler_type: "click"})
      {:ok, %Settings{}}

      iex> update_spoiler_type(actor, %{spoiler_type: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_spoiler_type(Actor.t(), map()) ::
          {:ok, Settings.t()} | {:error, :unauthorized | Ecto.Changeset.t()}
  def update_spoiler_type(%Actor{user: user} = actor, attrs) do
    with :ok <- authorize(actor, :update_spoiler_type, user) do
      user.settings
      |> Settings.spoiler_type_changeset(attrs)
      |> Repo.update()
    end
  end

  @doc group: "Settings"
  @doc """
  Updates a user's current filter.

  ## Examples

      iex> set_current_filter(user, filter)
      {:ok, %User{}}

  """
  @spec set_current_filter(User.t(), Filter.t()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def set_current_filter(%User{} = user, %Filter{} = filter) do
    Multi.new()
    |> Multi.lock_one(:locked_user, user_lock_query(user))
    |> Multi.update(:user, fn %{locked_user: user} -> User.filter_changeset(user, filter) end)
    |> put_reindex_user()
    |> Multi.transact()
    |> case do
      {:ok, %{user: %User{} = user}} ->
        {:ok, user}

      {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc group: "Settings"
  @doc """
  Clears a user's recent filter history.

  This personal preference update is deliberately exempt from
  `verify_write_access/1`, but the actor must be authorized to clear their own
  history.

  ## Examples

      iex> delete_recent_filters(actor)
      {:ok, %User{}}

  """
  @spec delete_recent_filters(Actor.t()) ::
          {:ok, User.t()} | {:error, :unauthorized | Ecto.Changeset.t()}
  def delete_recent_filters(%Actor{user: user} = actor) do
    with :ok <- authorize(actor, :delete_recent_filters, user) do
      Multi.new()
      |> Multi.lock_one(:locked_user, user_lock_query(user))
      |> Multi.update(:user, fn %{locked_user: user} ->
        User.clear_recent_filters_changeset(user)
      end)
      |> put_reindex_user()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Settings"
  @doc """
  Updates a user's general settings.

  This personal preference update is deliberately exempt from
  `verify_write_access/1`.

  ## Examples

      iex> update_settings(actor, %{"theme" => "dark"})
      {:ok, %User{}}

      iex> update_settings(actor, %{"theme" => bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_settings(Actor.t(), map()) ::
          {:ok, User.t()} | {:error, :unauthorized | Ecto.Changeset.t()}
  def update_settings(%Actor{user: %User{} = user}, attrs) do
    watched_tag_names = User.watched_tag_names(attrs)

    Multi.new()
    |> Tags.put_canonicalize_tag_name_sets([{:watched_tags, watched_tag_names, []}])
    |> Multi.lock_one(:locked_user, preload(user_lock_query(user), :settings))
    |> Multi.update(:user, fn
      %{
        locked_user: user,
        canonical_tags: %{watched_tags: watched_tags}
      } ->
        user
        |> User.settings_changeset(attrs)
        |> User.put_watched_tag_ids(Enum.map(watched_tags, & &1.id))
    end)
    |> put_reindex_user()
    |> Multi.transact_with_automatic_retry()
    |> case do
      {:ok, %{user: %User{} = user}} ->
        {:ok, user}

      {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc group: "Settings"
  @doc """
  Loads the user named by the profile `slug` for editing the description, on
  behalf of `actor`.

  A ban is checked before lookup; a missing fingerprint is not. Missing targets
  are `{:error, :not_found}`. Real targets are authorized for `:edit_description`.

  Returns the description `%Ecto.Changeset{}`; the loaded user is in
  `changeset.data`.

  ## Examples

      iex> edit_profile_description(actor, "somebody")
      {:ok, %Ecto.Changeset{}}

      iex> edit_profile_description(actor, "missing")
      {:error, :not_found}

  """
  @spec edit_profile_description(Actor.t(), String.t()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :unauthorized | :not_found}
  def edit_profile_description(%Actor{} = actor, slug) do
    with :ok <- verify_not_banned(actor),
         {:ok, user} <- load_user_by_slug(actor, :edit_description, slug) do
      {:ok, User.changeset(user)}
    end
  end

  @doc group: "Settings"
  @doc """
  Updates the description and personal title of the user named by the profile
  `slug`, on behalf of `actor`, from `attrs`.

  Write access is checked before lookup. Missing targets are
  `{:error, :not_found}`. Real targets are authorized for `:edit_description`
  following `load_profile_for_description_edit/2`. On success
  the description and personal title are updated and the user reindexed. A
  profile that gains an unapproved external link files a system report.

  Returns `{:ok, user}`, or the rejected `%Ecto.Changeset{}`.

  ## Examples

      iex> update_profile_description(actor, "somebody", %{"description" => "About me"})
      {:ok, %User{}}

      iex> update_profile_description(actor, "missing", %{})
      {:error, :not_found}

  """
  @spec update_profile_description(Actor.t(), String.t(), map()) ::
          {:ok, User.t()}
          | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def update_profile_description(%Actor{} = actor, slug, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_user_by_slug(actor, :edit_description, slug) do
      changeset = User.description_changeset(user, attrs)

      Multi.new()
      |> Multi.update(:user, changeset)
      |> Multi.merge(fn %{user: user} ->
        # credo:disable-for-next-line
        if user.became_unapproved? do
          Reports.put_create_system_report(
            Multi.new(),
            "Review",
            "Profile contains external links",
            :reported_user_id,
            user.id
          )
        else
          Multi.new()
        end
      end)
      |> put_reindex_user()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Settings"
  @doc """
  Adds a tag to a user's watched tags list.

  This personal preference update is deliberately exempt from
  `verify_write_access/1`.

  ## Examples

      iex> watch_tag(actor, tag)
      {:ok, %User{}}

  """
  @spec watch_tag(Actor.t(), Philomena.Tags.Tag.t()) ::
          {:ok, User.t()} | {:error, :unauthorized | Ecto.Changeset.t()}
  def watch_tag(%Actor{user: %User{} = user}, tag) do
    Multi.new()
    |> Tags.put_canonicalize_tag_name_sets([{:tag, [tag.name], []}])
    |> Multi.lock_one(:locked_user, user_lock_query(user))
    |> Multi.update(:user, fn %{locked_user: user, canonical_tags: %{tag: [tag]}} ->
      User.watched_tags_changeset(user, Enum.uniq([tag.id | user.watched_tag_ids]))
    end)
    |> Multi.transact_with_automatic_retry()
    |> case do
      {:ok, %{user: %User{} = user}} ->
        {:ok, user}

      {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc group: "Settings"
  @doc """
  Removes a tag from a user's watched tags list.

  This personal preference update is deliberately exempt from
  `verify_write_access/1`.

  ## Examples

      iex> unwatch_tag(actor, tag)
      {:ok, %User{}}

  """
  @spec unwatch_tag(Actor.t(), Philomena.Tags.Tag.t()) ::
          {:ok, User.t()} | {:error, :unauthorized | Ecto.Changeset.t()}
  def unwatch_tag(%Actor{user: %User{} = user}, tag) do
    Multi.new()
    |> Tags.put_canonicalize_tag_name_sets([{:tag, [tag.name], []}])
    |> Multi.lock_one(:locked_user, user_lock_query(user))
    |> Multi.update(:user, fn %{locked_user: user, canonical_tags: %{tag: [tag]}} ->
      User.watched_tags_changeset(user, user.watched_tag_ids -- [tag.id])
    end)
    |> put_reindex_user()
    |> Multi.transact_with_automatic_retry()
    |> case do
      {:ok, %{user: %User{} = user}} ->
        {:ok, user}

      {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc group: "Settings"
  @doc """
  Loads the avatar changeset for the acting user's own account, on behalf of
  `actor`.

  A ban is checked first, but a missing fingerprint is not; otherwise returns
  an `%Ecto.Changeset{}`.

  ## Examples

      iex> edit_avatar(actor)
      {:ok, %Ecto.Changeset{}}

      iex> edit_avatar(banned_actor)
      {:error, :ban}

  """
  @spec edit_avatar(Actor.t()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :unauthorized}
  def edit_avatar(%Actor{user: user} = actor) do
    with :ok <- verify_not_banned(actor) do
      {:ok, User.changeset(user)}
    end
  end

  @doc group: "Settings"
  @doc """
  Updates the acting user's own avatar from `attrs`, on behalf of `actor`.

  Write access is checked before lookup. Missing targets are
  `{:error, :not_found}`. On success the uploaded file is analyzed, persisted,
  and the user reindexed.

  Returns `{:ok, user}`, or the rejected `%Ecto.Changeset{}` when analysis or
  validation rejects the update.

  ## Examples

      iex> update_avatar(actor, upload)
      {:ok, %User{}}

      iex> update_avatar(banned_actor, upload)
      {:error, :ban}

  """
  @spec update_avatar(Actor.t(), PhilomenaMedia.Upload.t() | nil) ::
          {:ok, User.t()} | {:error, :ban | :unauthorized | Ecto.Changeset.t()}
  def update_avatar(%Actor{user: user} = actor, upload) do
    with :ok <- verify_write_access(actor) do
      changeset = Uploader.analyze_upload(user, upload)

      Multi.new()
      |> Multi.update(:user, changeset)
      |> Uploader.put_persist_upload_and_unpersist_old(:user)
      |> put_reindex_user()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Settings"
  @doc """
  Removes the acting user's own avatar, on behalf of `actor`.

  Write access is checked before lookup. Missing targets are
  `{:error, :not_found}`.

  Returns `{:ok, user}`.

  ## Examples

      iex> delete_avatar(actor)
      {:ok, %User{}}

      iex> delete_avatar(banned_actor)
      {:error, :ban}

  """
  @spec delete_avatar(Actor.t()) :: {:ok, User.t()} | {:error, :ban | :unauthorized}
  def delete_avatar(%Actor{user: user} = actor) do
    with :ok <- verify_write_access(actor) do
      clear_avatar(user)
    end
  end

  @doc group: "Settings"
  @doc """
  Loads the rename changeset for the acting user's own account, on behalf of
  `actor`.

  A ban is checked before lookup; a missing fingerprint is not. Renaming is
  authorized with `:change_username` against the actor's own user, which the
  ability rules gate on the 90-day rename window.

  Returns the editable `%Ecto.Changeset{}`.

  ## Examples

      iex> edit_name(actor)
      {:ok, %Ecto.Changeset{}}

      iex> edit_name(recently_renamed_actor)
      {:error, :unauthorized}

  """
  @spec edit_name(Actor.t()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :unauthorized}
  def edit_name(%Actor{user: user} = actor) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(user, :change_username, user) do
      {:ok, User.changeset(user)}
    end
  end

  @doc group: "Settings"
  @doc """
  Updates the acting user's own name from `user_params`, on behalf of `actor`,
  recording the change in history.

  Write access is checked before lookup. Renaming is authorized with
  `:change_username` against the actor's own user, which the ability rules gate on
  the 90-day rename window. On success the old name becomes a name-change row,
  the account is reindexed, and a background job rewrites references to the old
  username.

  Returns `{:ok, user}`, or the rejected `%Ecto.Changeset{}`.

  ## Examples

      iex> update_name(actor, %{"name" => "new_name"})
      {:ok, %User{}}

      iex> update_name(actor, %{"name" => ""})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_name(Actor.t(), map()) ::
          {:ok, User.t()} | {:error, :ban | :unauthorized | Ecto.Changeset.t()}
  def update_name(%Actor{user: user} = actor, user_params) do
    with :ok <- verify_write_access(actor) do
      old_name = user.name

      Multi.new()
      |> Multi.lock_one(:locked_user, user_lock_query(user))
      |> Multi.run(:authorize, fn _repo, %{locked_user: user} ->
        # credo:disable-for-next-line
        with :ok <- authorize(user, :change_username, user) do
          {:ok, nil}
        end
      end)
      |> Multi.update(:user, fn %{locked_user: user} ->
        User.name_changeset(user, user_params)
      end)
      |> UserNameChanges.record_rename(:name_change, user)
      |> put_reindex_user()
      |> put_rename_user_job(old_name: old_name)
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        {:error, :authorize, :unauthorized, _changes} ->
          {:error, :unauthorized}
      end
    end
  end

  ## Administration

  @doc group: "Administration"
  @doc """
  Runs the staff user search on behalf of `actor`, from `params` and
  `pagination`.

  Reading the user listing requires authorization to index users.

  The `query` param supplies the query, and `sf`/`sd` select the sort field
  and direction. Returns a `m:Scrivener.Page` of matching users and a
  changeset for a new search.

  ## Examples

      iex> query_users(actor, %{"query" => "name:somebody"}, pagination)
      {:ok, %Scrivener.Page{}, %Ecto.Changeset{}}

      iex> query_users(actor, %{"query" => "("}, pagination)
      {:error, %Ecto.Changeset{}}

  """
  @spec query_users(Actor.t(), map(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t(), Ecto.Changeset.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :unauthorized}
  def query_users(%Actor{} = actor, params, pagination) do
    with :ok <- authorize(actor, :index, User),
         {:ok, query, form} <- QueryBuilder.build_query(params) do
      users =
        User
        |> Search.search_definition(query, pagination)
        |> Search.search_records(User)

      {:ok, users, QueryForm.changeset(form)}
    end
  end

  @doc group: "Administration"
  @doc """
  Loads the user named by `slug` for editing, on behalf of `actor`.

  A ban is checked before lookup; a missing fingerprint is not. Missing targets
  are `{:error, :not_found}`; real targets are authorized for `:edit`.

  Returns an `%AdminUserForm{}` containing the changeset and assignable roles.

  ## Examples

      iex> edit_user(actor, "somebody")
      {:ok, %AdminUserForm{}}

      iex> edit_user(actor, "missing")
      {:error, :not_found}

  """
  @spec edit_user(Actor.t(), String.t()) ::
          {:ok, AdminUserForm.t()} | {:error, :ban | :unauthorized | :not_found}
  def edit_user(%Actor{} = actor, slug) do
    with :ok <- verify_not_banned(actor),
         {:ok, user} <- load_user_by_slug(actor, :edit, slug, [:roles]) do
      {:ok, admin_user_form(User.changeset(user))}
    end
  end

  @doc group: "Administration"
  @doc """
  Updates the details of the user named by `slug`, on behalf of `actor`, from
  `params`.

  Write access is checked before lookup. Missing targets are
  `{:error, :not_found}`; real targets are authorized for `:update`. On success
  the user is updated, reindexed, unsubscribed from any now-restricted forums,
  and a moderation log is written in the transaction.

  Returns `{:ok, user}`, or an `%AdminUserForm{}` containing the rejected
  changeset and assignable roles.

  ## Examples

      iex> update_user(actor, "somebody", %{"role" => "assistant"})
      {:ok, %User{}}

      iex> update_user(actor, "missing", %{})
      {:error, :not_found}

  """
  @spec update_user(Actor.t(), String.t(), map()) ::
          {:ok, User.t()}
          | {:error, :ban | :unauthorized | :not_found | AdminUserForm.t()}
  def update_user(%Actor{} = actor, slug, params) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_user_by_slug(actor, :update, slug, [:roles]) do
      Multi.new()
      |> Multi.lock_one(:locked_user, user_lock_query(user))
      |> Multi.update(:user, fn %{locked_user: user} ->
        update_user_changeset(user, params)
      end)
      |> put_unsubscribe_restricted_actors(:unsubscribe_restricted_actors)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{user: updated_user} ->
        {
          "Admin.User:update",
          Paths.profile_path(updated_user),
          "Updated user details for #{updated_user.name}"
        }
      end)
      |> put_reindex_user()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = updated_user}} ->
          {:ok, updated_user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, admin_user_form(changeset)}
      end
    end
  end

  @doc group: "Administration"
  @doc """
  Reactivates the deactivated user named by `slug`, on behalf of `actor`.

  Write access is checked before lookup. Missing targets are `{:error, :not_found}`;
  real targets are authorized with the action-specific ability. On success the
  account is reactivated, reindexed, and a moderation log is written.

  Returns `{:ok, user}`, or `{:error, changeset}` when the account is already active.

  ## Examples

      iex> create_user_activation(actor, "somebody")
      {:ok, %User{}}

      iex> create_user_activation(actor, "missing")
      {:error, :not_found}

  """
  @spec create_user_activation(Actor.t(), String.t()) ::
          {:ok, User.t()} | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def create_user_activation(%Actor{} = actor, slug) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_user_by_slug(actor, :reactivate, slug) do
      Multi.new()
      |> Multi.lock_one(:locked_user, user_lock_query(user))
      |> Multi.update(:user, fn %{locked_user: user} -> User.reactivate_changeset(user) end)
      |> Multi.delete_all(
        :reactivation_tokens,
        UserToken.user_and_contexts_query(user, ["reactivate"])
      )
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{user: user} ->
        {
          "Admin.User.Activation:create",
          Paths.profile_path(user),
          "Reactivated #{user.name}"
        }
      end)
      |> put_reindex_user()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Administration"
  @doc """
  Deactivates the user named by `slug`, on behalf of `actor`, recording `actor`
  as the deactivator.

  Write access is checked before lookup. Missing targets are `{:error, :not_found}`;
  real targets are authorized with the action-specific ability. On success the
  account is deactivated, reindexed, and a moderation log is written.

  Returns `{:ok, user}`, or `{:error, changeset}` when the account is already
  deactivated.

  ## Examples

      iex> delete_user_activation(actor, "somebody")
      {:ok, %User{}}

      iex> delete_user_activation(actor, "missing")
      {:error, :not_found}

  """
  @spec delete_user_activation(Actor.t(), String.t()) ::
          {:ok, User.t()} | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def delete_user_activation(%Actor{} = actor, slug) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_user_by_slug(actor, :deactivate, slug) do
      Multi.new()
      |> Multi.lock_one(:locked_user, user_lock_query(user))
      |> Multi.update(:user, fn %{locked_user: user} ->
        User.deactivate_changeset(user, actor.user)
      end)
      |> Multi.delete_all(
        :reactivation_tokens,
        UserToken.user_and_contexts_query(user, ["reactivate"])
      )
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{user: user} ->
        {"Admin.User.Activation:delete", Paths.profile_path(user), "Deactivated #{user.name}"}
      end)
      |> put_reindex_user()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Administration"
  @doc """
  Resets the API token of the user named by `slug`, on behalf of `actor`.

  Write access is checked before lookup. Missing targets are `{:error, :not_found}`;
  real targets are authorized with the action-specific ability. On success a
  fresh token is generated, the account reindexed, and a moderation log is
  written.

  Returns `{:ok, user}`.

  ## Examples

      iex> delete_user_api_key(actor, "somebody")
      {:ok, %User{}}

      iex> delete_user_api_key(actor, "missing")
      {:error, :not_found}

  """
  @spec delete_user_api_key(Actor.t(), String.t()) ::
          {:ok, User.t()} | {:error, :ban | :unauthorized | :not_found}
  def delete_user_api_key(%Actor{} = actor, slug) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_user_by_slug(actor, :reset_api_key, slug) do
      changeset = User.api_key_changeset(user)

      Multi.new()
      |> Multi.update(:user, changeset)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{user: user} ->
        {"Admin.User.ApiKey:delete", Paths.profile_path(user), "Reset API key for #{user.name}"}
      end)
      |> put_reindex_user()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Administration"
  @doc """
  Removes the avatar of the user named by `slug`, on behalf of `actor`.

  Write access is checked before lookup. Missing targets are `{:error, :not_found}`;
  real targets are authorized with the action-specific ability. On success the
  avatar is cleared, the old file unpersisted, the account reindexed, and a
  moderation log is written.

  Returns `{:ok, user}`.

  ## Examples

      iex> delete_user_avatar(actor, "somebody")
      {:ok, %User{}}

      iex> delete_user_avatar(actor, "missing")
      {:error, :not_found}

  """
  @spec delete_user_avatar(Actor.t(), String.t()) ::
          {:ok, User.t()} | {:error, :ban | :unauthorized | :not_found}
  def delete_user_avatar(%Actor{} = actor, slug) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_user_by_slug(actor, :remove_avatar, slug) do
      changeset = User.remove_avatar_changeset(user)

      Multi.new()
      |> Multi.update(:user, changeset)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{user: user} ->
        {"Admin.User.Avatar:delete", Paths.profile_path(user), "Removed avatar for #{user.name}"}
      end)
      |> put_reindex_user()
      |> Uploader.put_unpersist_old_upload(:user)
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Administration"
  @doc """
  Starts a downvote wipe for the user named by `slug`, on behalf of `actor`.

  Write access is checked before lookup. Missing targets are `{:error, :not_found}`;
  real targets are authorized with the action-specific ability. On success a
  background job removes the user's downvotes and a moderation log is written.

  Returns `{:ok, user}`.

  ## Examples

      iex> delete_user_downvotes(actor, "somebody")
      {:ok, %User{}}

      iex> delete_user_downvotes(actor, "missing")
      {:error, :not_found}

  """
  @spec delete_user_downvotes(Actor.t(), String.t()) ::
          {:ok, User.t()} | {:error, :ban | :unauthorized | :not_found}
  def delete_user_downvotes(%Actor{} = actor, slug) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_user_by_slug(actor, :wipe_downvotes, slug) do
      Multi.new()
      |> Multi.put(:user, user)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{user: user} ->
        {"Admin.User.Downvote:delete", Paths.profile_path(user),
         "Wiped downvotes for #{user.name}"}
      end)
      |> put_wipe_user_votes_job(upvotes_and_faves?: false)
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}
      end
    end
  end

  @doc group: "Administration"
  @doc """
  Loads the user named by `slug` for erasure, on behalf of `actor`, applying the
  eligibility guards.

  A ban is checked before lookup; a missing fingerprint is not. Missing targets
  are `{:error, :not_found}`; real targets are authorized with the `:erase` ability.
  Only ordinary, unverified accounts may be erased:

    * a privileged (non-`"user"` role) target is `{:error, {:privileged, user}}`;
    * a verified target is `{:error, {:verified, user}}`.

  Returns `{:ok, user}` for an erasable user, with its roles preloaded.

  ## Examples

      iex> new_user_erase(actor, "somebody")
      {:ok, %User{}}

      iex> new_user_erase(actor, "missing")
      {:error, :not_found}

  """
  @spec new_user_erase(Actor.t(), String.t()) ::
          {:ok, User.t()}
          | {:error,
             :ban | :unauthorized | :not_found | {:privileged, User.t()} | {:verified, User.t()}}
  def new_user_erase(%Actor{} = actor, slug) do
    with :ok <- verify_not_banned(actor),
         {:ok, user} <- load_user_by_slug(actor, :erase, slug, [:roles]) do
      cond do
        user.role != "user" -> {:error, {:privileged, user}}
        user.verified -> {:error, {:verified, user}}
        true -> {:ok, user}
      end
    end
  end

  @doc group: "Administration"
  @doc """
  Erases the user named by `slug`, on behalf of `actor`.

  Write access is verified, then the target is loaded and guarded following
  `new_user_erase/2`. On success
  the account is deactivated (unless it already is), renamed to a random
  handle, enqueued for the remaining data deletion, and a moderation log is
  written naming the original account.

  Returns `{:ok, user}` with the renamed account.

  ## Examples

      iex> create_user_erase(actor, "somebody")
      {:ok, %User{name: "deactivated_..."}}

      iex> create_user_erase(actor, "missing")
      {:error, :not_found}

  """
  @spec create_user_erase(Actor.t(), String.t()) ::
          {:ok, User.t()}
          | {:error,
             :ban
             | :unauthorized
             | :not_found
             | {:privileged, User.t()}
             | {:verified, User.t()}
             | Ecto.Changeset.t()}
  def create_user_erase(%Actor{} = actor, slug) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- new_user_erase(actor, slug) do
      random_hex = Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)

      Multi.new()
      |> Multi.lock_one(:locked_user, user_lock_query(user))
      |> Multi.update(:user, fn %{locked_user: user} ->
        changeset = update_user_changeset(user, %{"name" => "deactivated_#{random_hex}"})

        if user.deleted_at,
          do: changeset,
          else: User.deactivate_changeset(changeset, actor.user)
      end)
      |> Multi.delete_all(
        :reactivation_tokens,
        UserToken.user_and_contexts_query(user, ["reactivate"])
      )
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{locked_user: original, user: user} ->
        {"Admin.User.Erase:create", Paths.profile_path(user), "Erased #{original.name}"}
      end)
      |> put_reindex_user()
      |> put_erase_user_job(actor)
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Administration"
  @doc """
  Loads the user named by `slug` for forcing a filter, on behalf of `actor`.

  A ban is checked before lookup; a missing fingerprint is not. Missing targets
  are `{:error, :not_found}`. Real targets are authorized for `:force_filter`.

  Returns the force-filter `%Ecto.Changeset{}`; the loaded user is in
  `changeset.data`.

  ## Examples

      iex> new_user_force_filter(actor, "somebody")
      {:ok, %Ecto.Changeset{}}

      iex> new_user_force_filter(actor, "missing")
      {:error, :not_found}

  """
  @spec new_user_force_filter(Actor.t(), String.t()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :unauthorized | :not_found}
  def new_user_force_filter(%Actor{} = actor, slug) do
    with :ok <- verify_not_banned(actor),
         {:ok, user} <- load_user_by_slug(actor, :force_filter, slug) do
      {:ok, User.changeset(user)}
    end
  end

  @doc group: "Administration"
  @doc """
  Forces a filter on the user named by `slug`, on behalf of `actor`, from
  `params`.

  Write access is checked before lookup. Missing targets are `{:error, :not_found}`.
  Real targets are authorized for `:force_filter`. On success the
  filter is forced, the account reindexed, and a moderation log is written.

  Returns `{:ok, user}`.

  ## Examples

      iex> create_user_force_filter(actor, "somebody", %{"forced_filter_id" => filter.id})
      {:ok, %User{}}

      iex> create_user_force_filter(actor, "missing", %{})
      {:error, :not_found}

  """
  @spec create_user_force_filter(Actor.t(), String.t(), map()) ::
          {:ok, User.t()}
          | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def create_user_force_filter(%Actor{} = actor, slug, params) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_user_by_slug(actor, :force_filter, slug) do
      changeset = User.force_filter_changeset(user, params)

      Multi.new()
      |> Multi.update(:user, changeset)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{user: user} ->
        {"Admin.User.ForceFilter:create", Paths.profile_path(user),
         "Forced filter #{user.forced_filter_id} for #{user.name}"}
      end)
      |> put_reindex_user()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Administration"
  @doc """
  Removes the forced filter from the user named by `slug`, on behalf of `actor`.

  Write access is checked before lookup. Missing targets are `{:error, :not_found}`.
  Real targets are authorized for `:unforce_filter`. On success the
  forced filter is cleared, the account reindexed, and a moderation log is
  written.

  Returns `{:ok, user}`.

  ## Examples

      iex> delete_user_force_filter(actor, "somebody")
      {:ok, %User{}}

      iex> delete_user_force_filter(actor, "missing")
      {:error, :not_found}

  """
  @spec delete_user_force_filter(Actor.t(), String.t()) ::
          {:ok, User.t()} | {:error, :ban | :unauthorized | :not_found}
  def delete_user_force_filter(%Actor{} = actor, slug) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_user_by_slug(actor, :unforce_filter, slug) do
      changeset = User.unforce_filter_changeset(user)

      Multi.new()
      |> Multi.update(:user, changeset)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{user: user} ->
        {"Admin.User.ForceFilter:delete", Paths.profile_path(user),
         "Removed forced filter for #{user.name}"}
      end)
      |> put_reindex_user()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Administration"
  @doc """
  Unlocks the user named by `slug`, on behalf of `actor`.

  Write access is checked before lookup. Missing targets are `{:error, :not_found}`.
  Real targets are authorized for `:unlock`. On success the account is unlocked,
  reindexed, and a moderation log is written.

  Returns `{:ok, user}`.

  ## Examples

      iex> create_user_unlock(actor, "somebody")
      {:ok, %User{}}

      iex> create_user_unlock(actor, "missing")
      {:error, :not_found}

  """
  @spec create_user_unlock(Actor.t(), String.t()) ::
          {:ok, User.t()} | {:error, :ban | :unauthorized | :not_found}
  def create_user_unlock(%Actor{} = actor, slug) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_user_by_slug(actor, :unlock, slug) do
      changeset = User.unlock_changeset(user)

      Multi.new()
      |> Multi.update(:user, changeset)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{user: user} ->
        {"Admin.User.Unlock:create", Paths.profile_path(user), "Unlocked #{user.name}"}
      end)
      |> put_reindex_user()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Administration"
  @doc """
  Grants verification to the user named by `slug`, on behalf of `actor`.

  Write access is checked before lookup. Missing targets are `{:error, :not_found}`.
  Real targets are authorized for `:verify`. On success the account is verified,
  reindexed, and a moderation log is written.

  Returns `{:ok, user}`.

  ## Examples

      iex> create_user_verification(actor, "somebody")
      {:ok, %User{}}

      iex> create_user_verification(actor, "missing")
      {:error, :not_found}

  """
  @spec create_user_verification(Actor.t(), String.t()) ::
          {:ok, User.t()} | {:error, :ban | :unauthorized | :not_found}
  def create_user_verification(%Actor{} = actor, slug) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_user_by_slug(actor, :verify, slug) do
      changeset = User.verify_changeset(user)

      Multi.new()
      |> Multi.update(:user, changeset)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{user: user} ->
        {"Admin.User.Verification:create", Paths.profile_path(user),
         "Granted verification to #{user.name}"}
      end)
      |> put_reindex_user()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Administration"
  @doc """
  Revokes verification from the user named by `slug`, on behalf of `actor`.

  Write access is checked before lookup. Missing targets are `{:error, :not_found}`;
  real targets are authorized for `:unverify`. On success verification is revoked,
  the account reindexed, and a moderation log is written.

  Returns `{:ok, user}`.

  ## Examples

      iex> delete_user_verification(actor, "somebody")
      {:ok, %User{}}

      iex> delete_user_verification(actor, "missing")
      {:error, :not_found}

  """
  @spec delete_user_verification(Actor.t(), String.t()) ::
          {:ok, User.t()} | {:error, :ban | :unauthorized | :not_found}
  def delete_user_verification(%Actor{} = actor, slug) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_user_by_slug(actor, :unverify, slug) do
      changeset = User.unverify_changeset(user)

      Multi.new()
      |> Multi.update(:user, changeset)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{user: user} ->
        {"Admin.User.Verification:delete", Paths.profile_path(user),
         "Revoked verification from #{user.name}"}
      end)
      |> put_reindex_user()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Administration"
  @doc """
  Starts a vote and fave wipe for the user named by `slug`, on behalf of
  `actor`.

  Write access is checked before lookup. Missing targets are `{:error, :not_found}`.
  Real targets are authorized for `:wipe_votes`. On success a background job removes
  the user's votes and favorites and a moderation log is written.

  Returns `{:ok, user}`.

  ## Examples

      iex> delete_user_votes(actor, "somebody")
      {:ok, %User{}}

      iex> delete_user_votes(actor, "missing")
      {:error, :not_found}

  """
  @spec delete_user_votes(Actor.t(), String.t()) ::
          {:ok, User.t()} | {:error, :ban | :unauthorized | :not_found}
  def delete_user_votes(%Actor{} = actor, slug) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_user_by_slug(actor, :wipe_votes, slug) do
      Multi.new()
      |> Multi.put(:user, user)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{user: user} ->
        {"Admin.User.Vote:delete", Paths.profile_path(user),
         "Wiped votes and faves for #{user.name}"}
      end)
      |> put_wipe_user_votes_job(upvotes_and_faves?: true)
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}
      end
    end
  end

  @doc group: "Administration"
  @doc """
  Queues a PII wipe for the user named by `slug`, on behalf of `actor`.

  Write access is checked before lookup. Missing targets are `{:error, :not_found}`.
  Real targets are authorized for `:wipe`. On success a background job wipes the
  user's personally identifying information and a moderation log is written.

  Returns `{:ok, user}`.

  ## Examples

      iex> create_user_wipe(actor, "somebody")
      {:ok, %User{}}

      iex> create_user_wipe(actor, "missing")
      {:error, :not_found}

  """
  @spec create_user_wipe(Actor.t(), String.t()) ::
          {:ok, User.t()} | {:error, :ban | :unauthorized | :not_found}
  def create_user_wipe(%Actor{} = actor, slug) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_user_by_slug(actor, :wipe, slug) do
      Multi.new()
      |> Multi.put(:user, user)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{user: user} ->
        {"Admin.User.Wipe:create", Paths.profile_path(user), "Wiped PII for #{user.name}"}
      end)
      |> put_wipe_user_job()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}
      end
    end
  end

  @doc group: "Administration"
  @doc """
  Loads the potential aliases of the user named by the profile `slug`, on behalf
  of `actor`: other users who share one of the subject's IP addresses, one of
  its fingerprints, or both.

  Missing targets are `{:error, :not_found}`. Real targets are authorized for
  `:show_details`.

  Returns a typed alias page result with each match list carrying the matched
  users and their bans.

  ## Examples

      iex> list_profile_aliases(actor, "somebody")
      {:ok, %AliasMatches{}}

      iex> list_profile_aliases(actor, "missing")
      {:error, :not_found}

  """
  @spec list_profile_aliases(Actor.t(), String.t()) ::
          {:ok, AliasMatches.t()} | {:error, :unauthorized | :not_found}
  def list_profile_aliases(%Actor{} = actor, slug) do
    with {:ok, user} <- load_user_by_slug(actor, :show_details, slug) do
      # Select all IPs and fingerprints known from this user
      user_ips =
        UserIp
        |> where(user_id: ^user.id)
        |> select([ip], ip.ip)

      user_fingerprints =
        UserFingerprint
        |> where(user_id: ^user.id)
        |> select([fingerprint], fingerprint.fingerprint)

      # Select all user IDs that have ever shared those IPs/fingerprints
      ip_user_ids =
        UserIp
        |> where([ip], ip.ip in subquery(user_ips))
        |> select([ip], ip.user_id)

      fingerprint_user_ids =
        UserFingerprint
        |> where([fingerprint], fingerprint.fingerprint in subquery(user_fingerprints))
        |> select([fingerprint], fingerprint.user_id)

      # Select all users that match those user IDs and are not the target user
      ip_matches =
        User
        |> where([user], user.id != ^user.id and user.id in subquery(ip_user_ids))
        |> preload(:bans)
        |> Repo.all()
        |> Map.new(&{&1.id, &1})

      fingerprint_matches =
        User
        |> where([user], user.id != ^user.id and user.id in subquery(fingerprint_user_ids))
        |> preload(:bans)
        |> Repo.all()
        |> Map.new(&{&1.id, &1})

      both_matches = Map.take(ip_matches, Map.keys(fingerprint_matches))
      ip_matches = Map.drop(ip_matches, Map.keys(both_matches))
      fingerprint_matches = Map.drop(fingerprint_matches, Map.keys(both_matches))

      {:ok,
       %AliasMatches{
         user: user,
         both_matches: Map.values(both_matches),
         ip_matches: Map.values(ip_matches),
         fp_matches: Map.values(fingerprint_matches)
       }}
    end
  end

  @doc group: "Administration"
  @doc """
  Loads the user named by the profile `slug` for editing the moderation
  scratchpad, on behalf of `actor`.

  A ban is checked before lookup; a missing fingerprint is not. Missing targets
  are `{:error, :not_found}`. Real targets are authorized for `:edit_scratchpad`.

  Returns the scratchpad `%Ecto.Changeset{}`; the loaded user is in
  `changeset.data`.

  ## Examples

      iex> edit_profile_scratchpad(actor, "somebody")
      {:ok, %Ecto.Changeset{}}

      iex> edit_profile_scratchpad(actor, "missing")
      {:error, :not_found}

  """
  @spec edit_profile_scratchpad(Actor.t(), String.t()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :unauthorized | :not_found}
  def edit_profile_scratchpad(%Actor{} = actor, slug) do
    with :ok <- verify_not_banned(actor),
         {:ok, user} <- load_user_by_slug(actor, :edit_scratchpad, slug) do
      {:ok, User.changeset(user)}
    end
  end

  @doc group: "Administration"
  @doc """
  Updates the moderation scratchpad of the user named by the profile `slug`, on
  behalf of `actor`, from `params`.

  Write access is checked before lookup. Missing targets are
  `{:error, :not_found}`. Real targets are authorized for `:edit_scratchpad`.
  On success the scratchpad is updated and the user reindexed.

  Returns `{:ok, user}`, or the rejected `%Ecto.Changeset{}`.

  ## Examples

      iex> update_profile_scratchpad(actor, "somebody", %{"scratchpad" => "Staff note"})
      {:ok, %User{}}

      iex> update_profile_scratchpad(actor, "missing", %{})
      {:error, :not_found}

  """
  @spec update_profile_scratchpad(Actor.t(), String.t(), map()) ::
          {:ok, User.t()}
          | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def update_profile_scratchpad(%Actor{} = actor, slug, params) do
    with :ok <- verify_write_access(actor),
         {:ok, user} <- load_user_by_slug(actor, :edit_scratchpad, slug) do
      changeset = User.scratchpad_changeset(user, params)

      Multi.new()
      |> Multi.update(:user, changeset)
      |> put_reindex_user()
      |> Multi.transact()
      |> case do
        {:ok, %{user: %User{} = user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Cross-context helpers"
  @doc """
  Replaces a watched tag ID in users' watched-tag arrays within `multi`.
  """
  @spec put_replace_watched_tag(Multi.t(), Multi.name(), integer(), integer()) :: Multi.t()
  def put_replace_watched_tag(%Multi{} = multi, step, old_id, new_id) do
    query =
      User
      |> where([u], fragment("? @> ARRAY[?]::integer[]", u.watched_tag_ids, ^old_id))
      |> update([u],
        set: [
          watched_tag_ids: fragment("array_replace(?, ?, ?)", u.watched_tag_ids, ^old_id, ^new_id)
        ]
      )

    Multi.update_all(multi, step, query, [])
  end

  @doc group: "Cross-context helpers"
  @doc """
  Increments one lifetime counter on a user through the supplied repository.

  The return value is the normal `update_all/3` row count.
  """
  @spec increment_counter(module(), integer(), atom(), integer()) :: {non_neg_integer(), nil}
  def increment_counter(repo, user_id, field, amount)
      when is_integer(user_id) and is_atom(field) and is_integer(amount) do
    repo.update_all(where(User, id: ^user_id), inc: [{field, amount}])
  end

  @doc group: "Cross-context helpers"
  @doc """
  Increments one lifetime counter for each supplied user through the supplied
  repository.

  The return value is the normal `update_all/3` row count.
  """
  @spec increment_counters(module(), [integer()], atom(), integer()) :: {non_neg_integer(), nil}
  def increment_counters(repo, user_ids, field, amount)
      when is_list(user_ids) and is_atom(field) and is_integer(amount) do
    repo.update_all(where(User, [user], user.id in ^user_ids), inc: [{field, amount}])
  end

  @doc group: "Cross-context helpers"
  @doc """
  Replaces a user's email with the supplied erased address.
  """
  @spec replace_email_for_wipe!(integer(), String.t()) :: {non_neg_integer(), nil}
  def replace_email_for_wipe!(user_id, email) when is_integer(user_id) and is_binary(email) do
    Repo.update_all(where(User, id: ^user_id), set: [email: email])
  end

  @doc group: "Background jobs"
  @doc """
  Updates all search engine references to a user's old name with their new name.

  This is called as a background job after a user requests a name change.

  ## Examples

      iex> perform_rename("old_name", "new_name")
      :ok

  """
  @spec perform_rename(String.t(), String.t()) :: term()
  def perform_rename(old_name, new_name) do
    Images.user_name_reindex(old_name, new_name)
    Comments.user_name_reindex(old_name, new_name)
    Posts.user_name_reindex(old_name, new_name)
    Galleries.user_name_reindex(old_name, new_name)
    Reports.user_name_reindex(old_name, new_name)
    Filters.user_name_reindex(old_name, new_name)
    TagChanges.user_name_reindex(old_name, new_name)
    Users.user_name_reindex(old_name, new_name)
  end

  @doc group: "Background jobs"
  @doc """
  Queues a single user for search index updates.
  Returns the user struct unchanged, for use in a pipeline.

  ## Examples

      iex> reindex_user(user)
      %User{}

  """
  @spec reindex_user(User.t()) :: User.t()
  def reindex_user(%User{} = user) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Users", "id", [user.id]])

    user
  end

  @doc group: "Background jobs"
  @doc """
  Queues a list of user IDs for search index updates.
  Returns the list unchanged, for use in a pipeline.

  ## Examples

      iex> reindex_user_ids([1, 2, 3])
      [1, 2, 3]

  """
  @spec reindex_user_ids(list(integer())) :: list(integer())
  def reindex_user_ids(user_ids) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Users", "id", user_ids])

    user_ids
  end

  @doc group: "Background jobs"
  @doc """
  Loads a user by ID from a trusted background job.

  Job arguments originate from already persisted users, so an absent row is an
  invariant violation and intentionally raises.

  ## Examples

      iex> fetch_user_for_worker!(user.id)
      %User{}

  """
  @spec fetch_user_for_worker!(integer()) :: User.t()
  def fetch_user_for_worker!(id) when is_integer(id), do: Repo.get!(User, id)

  @doc group: "Background jobs"
  @doc """
  Loads the moderator for the account-erasure worker with role grants
  available for authorization.

  The erasure workflow uses the loaded role map when its synthetic system actor
  calls actor-scoped administration actions.
  """
  @spec fetch_user_for_erase!(integer()) :: User.t()
  def fetch_user_for_erase!(id) when is_integer(id) do
    User
    |> Repo.get!(id)
    |> Repo.preload(:roles)
    |> setup_roles()
  end

  @doc group: "Background jobs"
  @doc """
  Returns the preload configuration for user indexing.

  Specifies which associations should be preloaded when indexing users,
  optimizing the queries for better performance.

  ## Examples

      iex> indexing_preloads()
      [deleted_by_user: query, bans: query, name_changes: query]

  """
  @spec indexing_preloads() :: keyword(Ecto.Query.t())
  def indexing_preloads do
    user_query = select(User, [u], map(u, [:name]))
    ban_query = select(Bans.User, [b], map(b, [:enabled, :valid_until]))
    name_change_query = select(UserNameChange, [n], map(n, [:name]))

    [
      deleted_by_user: user_query,
      bans: ban_query,
      name_changes: name_change_query
    ]
  end

  @doc group: "Background jobs"
  @doc """
  Performs a search reindex operation on users matching the given criteria.

  ## Parameters
  - column: The database column to filter on (e.g., :id)
  - condition: A list of values to match against the column

  ## Examples

      iex> perform_reindex(:id, [1, 2, 3])
      :ok

  """
  @spec perform_reindex(atom(), [term()]) :: term()
  def perform_reindex(column, condition) do
    User
    |> preload(^indexing_preloads())
    |> where([i], field(i, ^column) in ^condition)
    |> Search.reindex(User)
  end

  @doc group: "Background jobs"
  @doc """
  Updates user search indices when a user's name changes.

  ## Examples

      iex> user_name_reindex("old_username", "new_username")
      :ok

  """
  @spec user_name_reindex(String.t(), String.t()) :: term()
  def user_name_reindex(old_name, new_name) do
    data = Users.SearchIndex.user_name_update_by_query(old_name, new_name)

    Search.update_by_query(User, data.query, data.set_replacements, data.replacements)
  end
end
