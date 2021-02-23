defmodule Philomena.Users do
  @moduledoc """
  The Users context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Users.{User, UserToken, UserNotifier, Uploader}
  alias Philomena.{Forums, Forums.Forum}
  alias Philomena.Topics
  alias Philomena.Roles.Role
  alias Philomena.UserNameChanges.UserNameChange
  alias Philomena.Images
  alias Philomena.Comments
  alias Philomena.Posts
  alias Philomena.Galleries
  alias Philomena.Reports
  alias Philomena.Filters
  alias Philomena.UserRenameWorker

  ## Database getters

  @doc """
  Gets a user by API token.

  ## Examples

      iex> get_user_by_authentication_token("5Ow89k7nW24E0K34d3zX")
      %User{}

      iex> get_user_by_authentication_token("invalid")
      nil

  """
  def get_user_by_authentication_token(token) when is_binary(token) do
    Repo.get_by(User, authentication_token: token)
  end

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password, unlock_url_fun)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)

    cond do
      is_nil(user) or not is_nil(user.locked_at) ->
        nil

      User.valid_password?(user, password) ->
        user
        |> User.successful_attempt_changeset()
        |> Repo.update!()

      true ->
        user
        |> User.failed_attempt_changeset()
        |> Repo.update!()
        |> maybe_send_unlock_instructions(unlock_url_fun)

        nil
    end
  end

  defp maybe_send_unlock_instructions(%{failed_attempts: attempts}, _unlock_url_fun)
       when attempts < 10 do
    nil
  end

  defp maybe_send_unlock_instructions(%User{} = user, unlock_url_fun) do
    user
    |> User.lock_changeset()
    |> Repo.update!()
    |> deliver_user_unlock_instructions(unlock_url_fun)

    nil
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email in token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset = user |> User.email_changeset(%{email: email}) |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @doc """
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_update_email_instructions(user, current_email, &Routes.user_update_email_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Unlocks the user by the given token.

  If the token matches, the user is marked as unlocked
  and the token is deleted.
  """
  def unlock_user_by_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "unlock"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(unlock_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp unlock_user_multi(user) do
    changeset = User.unlock_changeset(user)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["unlock"]))
  end

  @doc """
  Unconditionally unlocks the given user.
  """
  def unlock_user(user) do
    user
    |> User.unlock_changeset()
    |> Repo.update()
  end

  @doc """
  Delivers the unlock instructions to the given user.

  ## Examples

    iex> deliver_user_unlock_instructions(user, &Routes.unlock_url(conn, :show, &1))
    {:ok, %{to: ..., body: ...}}

  """
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

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Generates a TOTP token.
  """
  def generate_user_totp_token(user) do
    {token, user_token} = UserToken.build_totp_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    load_with_roles(query)
  end

  def user_totp_token_valid?(nil, _token) do
    false
  end

  def user_totp_token_valid?(user, token) do
    {:ok, query} = UserToken.verify_totp_token_query(user, token)
    Repo.exists?(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_totp_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "totp"))
    :ok
  end

  ## Confirmation

  @doc """
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &Routes.user_confirmation_url(conn, :confirm, &1))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &Routes.user_confirmation_url(conn, :confirm, &1))
      {:error, :already_confirmed}

  """
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

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc """
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &Routes.user_reset_password_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    roles =
      Role
      |> where([r], r.id in ^clean_roles(attrs["roles"]))
      |> Repo.all()

    changeset =
      user
      |> User.update_changeset(attrs, roles)

    Multi.new()
    |> Multi.update(:user, changeset)
    |> Multi.run(:unsubscribe, fn _repo, %{user: user} ->
      unsubscribe_restricted_actors(user)
    end)
    |> Repo.transaction()
  end

  defp clean_roles(nil), do: []
  defp clean_roles(roles), do: Enum.filter(roles, &("" != &1))

  def update_spoiler_type(%User{} = user, attrs) do
    user
    |> User.spoiler_type_changeset(attrs)
    |> Repo.update()
  end

  def update_settings(%User{} = user, attrs) do
    user
    |> User.settings_changeset(attrs)
    |> Repo.update()
  end

  def update_description(%User{} = user, attrs) do
    user
    |> User.description_changeset(attrs)
    |> Repo.update()
  end

  def update_scratchpad(%User{} = user, attrs) do
    user
    |> User.scratchpad_changeset(attrs)
    |> Repo.update()
  end

  def watch_tag(%User{} = user, tag) do
    watched_tag_ids = Enum.uniq([tag.id | user.watched_tag_ids])

    user
    |> User.watched_tags_changeset(watched_tag_ids)
    |> Repo.update()
  end

  def unwatch_tag(%User{} = user, tag) do
    watched_tag_ids = user.watched_tag_ids -- [tag.id]

    user
    |> User.watched_tags_changeset(watched_tag_ids)
    |> Repo.update()
  end

  def update_avatar(%User{} = user, attrs) do
    user
    |> Uploader.analyze_upload(attrs)
    |> Repo.update()
    |> case do
      {:ok, user} ->
        Uploader.persist_upload(user)
        Uploader.unpersist_old_upload(user)

        {:ok, user}

      error ->
        error
    end
  end

  def remove_avatar(%User{} = user) do
    user
    |> User.remove_avatar_changeset()
    |> Repo.update()
    |> case do
      {:ok, user} ->
        Uploader.unpersist_old_upload(user)

        {:ok, user}

      error ->
        error
    end
  end

  def update_name(user, user_params) do
    old_name = user.name

    name_change = UserNameChange.changeset(%UserNameChange{user_id: user.id}, user.name)
    account = User.name_changeset(user, user_params)

    Multi.new()
    |> Multi.insert(:name_change, name_change)
    |> Multi.update(:account, account)
    |> Repo.transaction()
    |> case do
      {:ok, %{account: %{name: new_name} = account}} ->
        Exq.enqueue(Exq, "indexing", UserRenameWorker, [old_name, new_name])

        {:ok, account}

      {:error, :account, changeset, _changes} ->
        {:error, changeset}
    end
  end

  def perform_rename(old_name, new_name) do
    Images.user_name_reindex(old_name, new_name)
    Comments.user_name_reindex(old_name, new_name)
    Posts.user_name_reindex(old_name, new_name)
    Galleries.user_name_reindex(old_name, new_name)
    Reports.user_name_reindex(old_name, new_name)
    Filters.user_name_reindex(old_name, new_name)
  end

  def reactivate_user(%User{} = user) do
    user
    |> User.reactivate_changeset()
    |> Repo.update()
  end

  def deactivate_user(moderator, %User{} = user) do
    user
    |> User.deactivate_changeset(moderator)
    |> Repo.update()
  end

  def reset_api_key(%User{} = user) do
    user
    |> User.api_key_changeset()
    |> Repo.update()
  end

  def force_filter(%User{} = user, user_params) do
    user
    |> User.force_filter_changeset(user_params)
    |> Repo.update()
  end

  def unforce_filter(%User{} = user) do
    user
    |> User.unforce_filter_changeset()
    |> Repo.update()
  end

  def clear_recent_filters(%User{} = user) do
    user
    |> User.clear_recent_filters_changeset()
    |> Repo.update()
  end

  defp load_with_roles(query) do
    query
    |> Repo.one()
    |> Repo.preload([:roles, :current_filter])
    |> setup_roles()
  end

  defp setup_roles(nil), do: nil

  defp setup_roles(user) do
    role_map = Map.new(user.roles, &{&1.resource_type || &1.name, &1.name})

    %{user | role_map: role_map}
  end

  defp unsubscribe_restricted_actors(%User{} = user) do
    forum_ids =
      Forum
      |> order_by(asc: :name)
      |> Repo.all()
      |> Enum.reject(&Canada.Can.can?(user, :show, &1))
      |> Enum.map(& &1.id)

    {_count, nil} =
      Forums.Subscription
      |> where([s], s.user_id == ^user.id and s.forum_id in ^forum_ids)
      |> Repo.delete_all()

    {_count, nil} =
      Topics.Subscription
      |> join(:inner, [s], _ in assoc(s, :topic))
      |> where([s, t], s.user_id == ^user.id and t.forum_id in ^forum_ids)
      |> Repo.delete_all()

    {:ok, nil}
  end
end
