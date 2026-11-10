defmodule Philomena.UsersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Users` context.
  """

  alias Philomena.AttributionFixtures
  alias Philomena.Bans
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Users
  alias Philomena.Repo

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def user_fixture(attrs \\ %{}) do
    email = unique_user_email()

    {:ok, user} =
      Users.create_registration(
        AttributionFixtures.actor(),
        Enum.into(attrs, %{
          name: email,
          email: email,
          password: valid_user_password()
        })
      )

    user
  end

  def confirmed_user_fixture(attrs \\ %{}) do
    user_fixture(attrs)
    |> Users.User.confirm_changeset()
    |> Repo.update!()
  end

  def locked_user_fixture(attrs \\ %{}) do
    user_fixture(attrs)
    |> Users.User.lock_changeset()
    |> Repo.update!()
  end

  def assistant_user_fixture(attrs \\ %{}) do
    confirmed_user_fixture(attrs)
    |> Ecto.Changeset.change(role: "assistant")
    |> Repo.update!()
  end

  def moderator_user_fixture(attrs \\ %{}) do
    confirmed_user_fixture(attrs)
    |> Ecto.Changeset.change(role: "moderator")
    |> Repo.update!()
  end

  def admin_user_fixture(attrs \\ %{}) do
    confirmed_user_fixture(attrs)
    |> Ecto.Changeset.change(role: "admin")
    |> Repo.update!()
  end

  @doc """
  Fixture for a moderator granted the `resource_type` admin `role_map` entry
  (e.g. `%{"Image" => %{"admin" => []}}`), the shape the auth pipeline computes
  from a `users_roles` grant. Use where an ability keys on a resource-specific
  admin grant rather than the plain moderator role. The `role_map` is set on the
  returned struct the way a request-loaded actor carries it.
  """
  def role_moderator_fixture(resource_type) do
    user = moderator_user_fixture()
    role = Repo.insert!(%Philomena.Roles.Role{name: "admin", resource_type: resource_type})
    Repo.insert_all("users_roles", [%{user_id: user.id, role_id: role.id}])
    %{user | role_map: %{resource_type => %{"admin" => []}}}
  end

  @doc """
  Fixture for a user granted all given roles.
  Use where an ability keys on a resource-specific admin grant rather than the
  plain moderator role. The `role_map` is set on the returned struct the way
  a request-loaded actor carries it.
  """
  def role_user_fixture(attrs \\ %{}, role, roles) do
    user =
      confirmed_user_fixture(attrs)
      |> Ecto.Changeset.change(role: role)
      |> Repo.update!()

    for {name, resource_type} <- roles do
      role = Repo.insert!(%Philomena.Roles.Role{name: name, resource_type: resource_type})
      Repo.insert_all("users_roles", [%{user_id: user.id, role_id: role.id}])
    end

    role_map =
      user
      |> Repo.preload(:roles, force: true)
      |> Map.fetch!(:roles)
      |> Enum.group_by(& &1.resource_type, & &1.name)
      |> Map.new(fn {type, names} -> {type, Map.new(names, &{&1, []})} end)

    %{user | role_map: role_map}
  end

  @doc """
  Fixture for an assistant granted the `resource_type` moderator `role_map` entry
  (e.g. `%{"DuplicateReport" => %{"moderator" => []}}`), the shape the auth pipeline
  computes from a `users_roles` grant. Use where an ability keys on a resource-specific
  admin grant rather than the plain moderator role. The `role_map` is set on the
  returned struct the way a request-loaded actor carries it.
  """
  def role_assistant_fixture(resource_type, attrs \\ %{}) do
    user = assistant_user_fixture(attrs)
    role = Repo.insert!(%Philomena.Roles.Role{name: "moderator", resource_type: resource_type})
    Repo.insert_all("users_roles", [%{user_id: user.id, role_id: role.id}])
    %{user | role_map: %{resource_type => %{"moderator" => []}}}
  end

  @doc """
  Fixture for a confirmed user that has an avatar set (a bare filename in the
  `avatar` column; no object is actually uploaded).
  """
  def user_with_avatar_fixture(attrs \\ %{}) do
    confirmed_user_fixture(attrs)
    |> Ecto.Changeset.change(avatar: "test/avatar.png")
    |> Repo.update!()
  end

  @doc """
  Fixture for a confirmed user marked as verified (auto-approval status).
  """
  def verified_user_fixture(attrs \\ %{}) do
    confirmed_user_fixture(attrs)
    |> Users.User.verify_changeset()
    |> Repo.update!()
  end

  @doc """
  Fixture for a confirmed user with an active ban.

  The ban is issued by `banning_user` (a fresh admin when `nil`), has the
  reason "Banned in test", and is valid for one year.
  """
  def banned_user_fixture(banning_user \\ nil, attrs \\ %{}) do
    user = confirmed_user_fixture(attrs)

    banning_user = banning_user || admin_user_fixture()

    {:ok, ban} =
      Bans.create_user_ban(AttributionFixtures.actor(banning_user), user.id, %{
        "reason" => "Banned in test",
        "valid_until" => DateTime.add(DateTime.utc_now(:second), 365, :day)
      })

    ModerationLog
    |> Repo.get_by!(
      user_id: banning_user.id,
      type: "Admin.UserBan:create",
      body: "Created a user ban #{ban.generated_ban_id}"
    )
    |> Repo.delete!()

    user
  end

  @doc """
  Fixture for a confirmed user with TOTP (2FA) enabled.

  The generated secret can be recovered with `Philomena.Users.User.totp_secret/1`
  to produce valid codes in tests that exercise the TOTP flow itself; for
  everything else, use `PhilomenaWeb.ConnCase.log_in_totp_user/2`.
  """
  def totp_user_fixture(attrs \\ %{}) do
    hashed_backup_codes =
      Users.User.random_backup_codes()
      |> Enum.map(&Users.Password.hash_pwd_salt/1)

    confirmed_user_fixture(attrs)
    |> Users.User.create_totp_secret_changeset()
    |> Ecto.Changeset.change(
      otp_required_for_login: true,
      otp_backup_codes: hashed_backup_codes
    )
    |> Repo.update!()
  end

  @doc """
  Fixture for a deactivated user.

  If `deactivated_by_user` is `nil` the user will be deactivated by themselves.
  """
  def deactivated_user_fixture(deactivated_by_user \\ nil, attrs \\ %{}) do
    user = user_fixture(attrs)

    user
    |> Users.User.deactivate_changeset(deactivated_by_user || user)
    |> Repo.update!()
  end

  def extract_user_token(fun) do
    {:ok, captured} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token, _] = String.split(captured.text_body, "[TOKEN]")
    token
  end
end
