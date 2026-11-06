defmodule Philomena.UsersTest do
  use Philomena.DataCase, async: false

  @moduletag :search

  alias Philomena.Users
  import Philomena.UsersFixtures
  import Philomena.AttributionFixtures
  import Philomena.UserIpsFixtures
  import Philomena.UserFingerprintsFixtures
  import Philomena.FiltersFixtures
  import Philomena.RulesFixtures
  alias Philomena.Roles.Role
  alias Philomena.ModerationLogs.{ModerationLog, Paths}
  alias Philomena.Reports.Report
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers
  alias Philomena.Users.{AdminUserForm, AliasMatches, Settings, User, UserToken}
  alias Philomena.Repo
  alias PhilomenaMedia.Upload

  @png_fixture Path.absname("test/support/fixtures/files/upload-test.png")

  @pagination %{page_number: 1, page_size: 25}

  # A truthy ban value in the shape production passes; only its presence matters
  # to the write-access and not-banned checks the profile loaders run first.
  @ban %{
    reason: "Rule #0",
    valid_until: ~U[3000-01-01 00:00:00Z],
    generated_ban_id: "U123456",
    type: "User"
  }

  # A Plug.Upload whose tempfile is registered to the test process, the way
  # Plug.Parsers would provide it.
  defp png_upload do
    {:ok, path} = Plug.Upload.random_file("avatar-test")
    File.cp!(@png_fixture, path)
    %Plug.Upload{path: path, content_type: "image/png", filename: "upload-test.png"}
  end

  defp media_png_upload do
    png_upload()
    |> Upload.from_plug()
  end

  defp valid_totp_code(user), do: :pot.totp(User.totp_secret(user))

  # Controller-shaped params for enabling or disabling TOTP: current password
  # plus a live second-factor code computed from the user's stored secret.
  defp totp_params(token) do
    %{"user" => %{"current_password" => valid_user_password(), "twofactor_token" => token}}
  end

  # A confirmed user with a role and, optionally, a secondary role and the
  # hide-default-role flag, in the shape the staff page groups on.
  defp staff_user(role, opts \\ []) do
    confirmed_user_fixture()
    |> Ecto.Changeset.change(
      role: role,
      secondary_role: Keyword.get(opts, :secondary_role),
      hide_default_role: Keyword.get(opts, :hide_default_role, false)
    )
    |> Repo.update!()
  end

  # A confirmed user reloaded from the database, so its last_renamed_at carries
  # the 1970 column default the way a request-loaded actor does. A freshly
  # inserted struct instead has last_renamed_at nil, which the :change_username
  # ability's DateTime.diff cannot handle - the request pipeline never sees that
  # struct.
  defp renameable_user do
    Users.fetch_user_for_worker!(confirmed_user_fixture().id)
  end

  # A user whose rename window is closed: last_renamed_at is now, so the
  # :change_username ability (which requires the last rename to be over 90 days
  # ago) refuses.
  defp recently_renamed_user do
    confirmed_user_fixture()
    |> Ecto.Changeset.change(last_renamed_at: DateTime.utc_now(:second))
    |> Repo.update!()
  end

  # A confirmed user with a slug-clean name, used as the target of the staff
  # user-management functions so subject paths and log bodies read predictably.
  defp managed_target(name \\ "managed_target_#{System.unique_integer([:positive])}") do
    confirmed_user_fixture(%{name: name})
  end

  # A moderator carrying the "User" admin role_map grant. The user-management
  # ability keys on the "moderator" sub-grant instead, so this actor is
  # authorized for :index but rejected for :edit/:update - the almost-privileged
  # role.
  defp user_admin_moderator, do: role_moderator_fixture("User")

  # A syntactically valid watch query: `count` tag terms joined with `||`.
  defp watch_query(count) do
    Enum.map_join(1..count, " || ", &"watched_term_#{&1}")
  end

  # A valid watch query longer than the 10,000-byte settings cap.
  defp over_cap_watch_query do
    query = watch_query(700)
    true = byte_size(query) > 10_000
    query
  end

  # The most recently written moderation log row.
  defp last_moderation_log do
    ModerationLog |> order_by(desc: :id) |> limit(1) |> Repo.one()
  end

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Users.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Users.get_user_by_email(user.email)
    end
  end

  describe "fetch_user_by_email_and_password/3" do
    test "does not return the user if the email does not exist" do
      assert Users.fetch_user_by_email_and_password("unknown@example.com", "hello world!", & &1) ==
               {:error, :not_found}
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()

      assert Users.fetch_user_by_email_and_password(user.email, "invalid", & &1) ==
               {:error, :not_found}

      user = Users.fetch_user_for_worker!(user.id)
      assert user.failed_attempts == 1
    end

    test "sends lock email if too many attempts to sign in are made" do
      user = user_fixture()

      Enum.map(1..10, fn _ ->
        assert Users.fetch_user_by_email_and_password(user.email, "invalid", & &1) ==
                 {:error, :not_found}
      end)

      user = Users.fetch_user_for_worker!(user.id)

      token =
        extract_user_token(fn url ->
          Users.deliver_user_unlock_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "unlock"
      assert user.failed_attempts == 10
      refute is_nil(user.locked_at)
    end

    test "denies access to account if locked" do
      user = user_fixture()

      Enum.map(1..10, fn _ ->
        assert Users.fetch_user_by_email_and_password(user.email, "invalid", & &1) ==
                 {:error, :not_found}
      end)

      assert Users.fetch_user_by_email_and_password(user.email, valid_user_password(), & &1) ==
               {:error, :not_found}
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = confirmed_user_fixture()

      assert {:ok, %User{id: ^id}} =
               Users.fetch_user_by_email_and_password(user.email, valid_user_password(), & &1)
    end
  end

  describe "load_profile/2" do
    test "loads an active profile for an actor" do
      user = confirmed_user_fixture()

      assert {:ok, loaded} = Users.load_profile(actor(), user.slug)
      assert loaded.id == user.id
    end

    test "hides missing profiles from everyone and deactivated profiles from non-staff" do
      user = deactivated_user_fixture()

      for viewer <- [actor(), actor(confirmed_user_fixture())] do
        assert Users.load_profile(viewer, "missing-profile") == {:error, :not_found}
        assert Users.load_profile(viewer, user.slug) == {:error, :not_found}
      end

      for viewer <- [actor(moderator_user_fixture()), actor(admin_user_fixture())] do
        assert Users.load_profile(viewer, "missing-profile") == {:error, :not_found}
        assert {:ok, %{id: id}} = Users.load_profile(viewer, user.slug)
        assert id == user.id
      end
    end
  end

  describe "show_profile/2" do
    test "loads an active profile and its public associations" do
      user = confirmed_user_fixture()

      assert {:ok, loaded} = Users.show_profile(actor(), user.id)
      assert loaded.id == user.id
      assert is_list(loaded.public_links)
      assert is_list(loaded.awards)
    end

    test "normalizes malformed, missing, and deactivated IDs to not-found" do
      user =
        confirmed_user_fixture()
        |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second))
        |> Repo.update!()

      for viewer <- [actor(), actor(confirmed_user_fixture()), actor(admin_user_fixture())],
          id <- ["not-an-id", -1, user.id] do
        assert Users.show_profile(viewer, id) == {:error, :not_found}
      end
    end
  end

  describe "create_registration/2" do
    test "rejects banned actors" do
      assert Users.create_registration(actor(nil, ban: @ban), %{}) == {:error, :ban}
    end

    test "requires email and password to be set" do
      {:error, changeset} = Users.create_registration(actor(), %{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} =
        Users.create_registration(actor(), %{email: "not valid", password: "not valid"})

      assert %{
               email: ["must be valid (e.g., user@example.com)"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Users.create_registration(actor(), %{email: too_long, password: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()

      {:error, changeset} =
        Users.create_registration(actor(), %{
          name: email,
          password: valid_user_password(),
          email: email
        })

      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} =
        Users.create_registration(actor(), %{
          name: String.upcase(email),
          email: String.upcase(email),
          password: valid_user_password()
        })

      assert "has already been taken" in errors_on(changeset).email
    end

    test "rejects a name that differs from an existing name only by letter case" do
      %{name: name} = user_fixture(%{name: "CaseName#{System.unique_integer([:positive])}"})

      for variant <- [String.downcase(name), String.upcase(name)] do
        email = unique_user_email()

        assert {:error, %Ecto.Changeset{} = changeset} =
                 Users.create_registration(actor(), %{
                   name: variant,
                   email: email,
                   password: valid_user_password()
                 })

        assert %{name: ["has already been taken"]} = errors_on(changeset)

        assert {_message, [constraint: :unique, constraint_name: "index_users_on_lower_name"]} =
                 changeset.errors[:name]

        refute Repo.get_by(User, email: email)
        refute Repo.get_by(User, name: variant)
      end
    end

    test "registers users with a hashed password" do
      email = unique_user_email()

      {:ok, user} =
        Users.create_registration(actor(), %{
          name: email,
          email: email,
          password: valid_user_password()
        })

      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end

    test "creates the associated user_settings row" do
      email = unique_user_email()

      {:ok, user} =
        Users.create_registration(actor(), %{
          name: email,
          email: email,
          password: valid_user_password()
        })

      settings = Repo.get!(Settings, user.id)
      assert settings.user_id == user.id
      assert settings.spoiler_type == "static"
      assert settings.theme == "dark-blue"
      assert settings.images_per_page == 15

      assert %Settings{} = user.settings
      assert user.settings.user_id == user.id
    end
  end

  describe "new_registration/3" do
    test "returns a changeset" do
      assert {:ok, %Ecto.Changeset{} = changeset} = Users.new_registration(actor(), %User{})
      assert changeset.required == [:password, :email, :name]
    end

    test "rejects banned actors" do
      assert Users.new_registration(actor(nil, ban: @ban), %User{}) == {:error, :ban}
    end
  end

  describe "change_user_email/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Users.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "create_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} = Users.create_email(user, valid_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} =
        Users.create_email(user, valid_user_password(), %{email: "not valid"})

      assert %{email: ["must be valid (e.g., user@example.com)"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Users.create_email(user, valid_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{user: user} do
      %{email: email} = user_fixture()

      {:error, changeset} = Users.create_email(user, valid_user_password(), %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{user: user} do
      {:error, changeset} = Users.create_email(user, "invalid", %{email: unique_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user: user} do
      email = unique_user_email()
      {:ok, user} = Users.create_email(user, valid_user_password(), %{email: email})
      assert user.email == email
      assert Users.fetch_user_for_worker!(user.id).email != email
    end
  end

  describe "deliver_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "show_email/2" do
    setup do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Users.deliver_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert Users.show_email(user, token) == :ok
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      assert changed_user.confirmed_at
      assert changed_user.confirmed_at != user.confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Users.show_email(user, "oops") == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Users.show_email(%{user | email: "current@example.com"}, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [created_at: ~N[2020-01-01 00:00:00]])
      assert Users.show_email(user, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "edit_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Users.edit_password(%User{})
      assert changeset.required == [:password]
    end
  end

  describe "update_password/3" do
    setup do
      %{user: confirmed_user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Users.update_password(user, valid_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 200)

      {:error, changeset} =
        Users.update_password(user, valid_user_password(), %{password: too_long})

      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Users.update_password(user, "invalid", %{password: valid_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        Users.update_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(user.password)

      assert {:ok, _} =
               Users.fetch_user_by_email_and_password(user.email, "new valid password", & &1)
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Users.generate_user_session_token(user)

      {:ok, _} =
        Users.update_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Users.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Users.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Users.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Users.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [created_at: ~N[2019-01-01 00:00:00]])
      refute Users.get_user_by_session_token(token)
    end
  end

  describe "delete_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Users.generate_user_session_token(user)
      assert Users.delete_session_token(token) == :ok
      refute Users.get_user_by_session_token(token)
    end
  end

  describe "delete_user_sessions/1" do
    test "deletes all of the user's sessions" do
      user = user_fixture()
      first_token = Users.generate_user_session_token(user)
      second_token = Users.generate_user_session_token(user)
      totp_token = Users.generate_user_totp_token(user)

      assert Users.delete_user_sessions(user) == :ok
      refute Users.get_user_by_session_token(first_token)
      refute Users.get_user_by_session_token(second_token)
      refute Users.user_totp_token_valid?(user, totp_token)
    end
  end

  describe "generate_user_totp_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Users.generate_user_totp_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "totp"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "totp"
        })
      end
    end
  end

  describe "user_totp_token_valid?/1" do
    setup do
      user = user_fixture()
      token = Users.generate_user_totp_token(user)
      %{user: user, token: token}
    end

    test "returns true for valid token", %{user: user, token: token} do
      assert Users.user_totp_token_valid?(user, token)
    end

    test "returns false for invalid token", %{user: user} do
      refute Users.user_totp_token_valid?(user, "oops")
    end

    test "returns false for expired token", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [created_at: ~N[2019-01-01 00:00:00]])
      refute Users.user_totp_token_valid?(user, token)
    end
  end

  describe "delete_totp_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Users.generate_user_totp_token(user)
      assert Users.delete_totp_token(token) == :ok
      refute Users.user_totp_token_valid?(user, token)
    end
  end

  describe "deliver_user_confirmation_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "confirm"
    end
  end

  describe "update_confirmation/2" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Users.deliver_user_confirmation_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "confirms the email with a valid token", %{user: user, token: token} do
      assert {:ok, confirmed_user} = Users.update_confirmation(token)
      assert confirmed_user.confirmed_at
      assert confirmed_user.confirmed_at != user.confirmed_at
      assert Repo.get!(User, user.id).confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm with invalid token", %{user: user} do
      assert Users.update_confirmation("oops") == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [created_at: ~N[2020-01-01 00:00:00]])
      assert Users.update_confirmation(token) == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "deliver_user_unlock_instructions/2" do
    setup do
      %{user: locked_user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_user_unlock_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "unlock"
    end
  end

  describe "show_unlock/1" do
    setup do
      user = locked_user_fixture()

      token =
        extract_user_token(fn url ->
          Users.deliver_user_unlock_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "unlocks the user with a valid token", %{user: user, token: token} do
      assert {:ok, unlocked_user} = Users.show_unlock(token)
      refute unlocked_user.locked_at
      refute Repo.get!(User, user.id).locked_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm with invalid token", %{user: user} do
      assert Users.show_unlock("oops") == :error
      assert Repo.get!(User, user.id).locked_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not unlocked if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [created_at: ~N[2020-01-01 00:00:00]])
      assert Users.show_unlock(token) == :error
      assert Repo.get!(User, user.id).locked_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "deliver_user_reset_password_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_user_reset_password_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "reset_password"
    end
  end

  describe "get_user_by_reset_password_token/2" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Users.deliver_user_reset_password_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "returns the user with valid token", %{user: %{id: id}, token: token} do
      assert %User{id: ^id} = Users.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: id)
    end

    test "does not return the user with invalid token", %{user: user} do
      refute Users.get_user_by_reset_password_token("oops")
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not return the user if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [created_at: ~N[2020-01-01 00:00:00]])
      refute Users.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "update_password/2" do
    setup do
      %{user: confirmed_user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Users.update_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Users.update_password(user, %{password: too_long})
      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, updated_user} = Users.update_password(user, %{password: "new valid password"})
      assert is_nil(updated_user.password)

      assert {:ok, _} =
               Users.fetch_user_by_email_and_password(user.email, "new valid password", & &1)
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Users.generate_user_session_token(user)
      {:ok, _} = Users.update_password(user, %{password: "new valid password"})
      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "inspect/2" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  describe "update_settings/2" do
    for field <- ~w(watched_images_query_str watched_images_exclude_str) do
      test "rejects a valid #{field} over 10,000 bytes and leaves it unchanged" do
        user = confirmed_user_fixture()
        field = unquote(field)
        query = over_cap_watch_query()
        before = Map.fetch!(Repo.get!(Settings, user.id), String.to_existing_atom(field))

        # The value compiles as a watch query, so length is its only fault.
        assert {:ok, _} =
                 Philomena.Images.Query.compile(query,
                   user: Repo.preload(user, :settings),
                   watch: true
                 )

        assert {:error, %Ecto.Changeset{} = changeset} =
                 Users.update_settings(actor(user), %{"settings" => %{field => query}})

        assert errors_on(changeset).settings == %{
                 String.to_existing_atom(field) => ["should be at most 10000 byte(s)"]
               }

        assert Map.fetch!(Repo.get!(Settings, user.id), String.to_existing_atom(field)) ==
                 before
      end
    end

    test "saves a valid watch query longer than 255 characters" do
      user = confirmed_user_fixture()

      query =
        "(safe || suggestive) AND score.gte:100 AND -" <>
          "(#{watch_query(20)}) AND created_at.gte:3 years ago"

      assert String.length(query) > 300
      assert byte_size(query) < 10_000

      assert {:ok, %User{}} =
               Users.update_settings(actor(user), %{
                 "settings" => %{
                   "watched_images_query_str" => query,
                   "watched_images_exclude_str" => query
                 }
               })

      settings = Repo.get!(Settings, user.id)
      assert settings.watched_images_query_str == query
      assert settings.watched_images_exclude_str == query
    end

    test "a stored over-cap query does not block resubmitting it with another change" do
      user = confirmed_user_fixture()
      query = over_cap_watch_query()

      {1, _} =
        Settings
        |> where(user_id: ^user.id)
        |> Repo.update_all(set: [watched_images_query_str: query])

      assert {:ok, %User{}} =
               Users.update_settings(actor(user), %{
                 "settings" => %{"images_per_page" => "30", "watched_images_query_str" => query}
               })

      settings = Repo.get!(Settings, user.id)
      assert settings.images_per_page == 30
      assert settings.watched_images_query_str == query
    end

    test "a stored over-cap query does not block a change that omits it" do
      user = confirmed_user_fixture()
      query = over_cap_watch_query()

      {1, _} =
        Settings
        |> where(user_id: ^user.id)
        |> Repo.update_all(set: [watched_images_exclude_str: query])

      assert {:ok, %User{}} =
               Users.update_settings(actor(user), %{"settings" => %{"images_per_page" => "30"}})

      settings = Repo.get!(Settings, user.id)
      assert settings.images_per_page == 30
      assert settings.watched_images_exclude_str == query
    end
  end

  describe "edit_profile_description/2" do
    test "the profile owner may edit their own description" do
      user = confirmed_user_fixture()

      assert {:ok, %Ecto.Changeset{data: loaded}} =
               Users.edit_profile_description(actor(user), user.slug)

      assert loaded.id == user.id
    end

    test "a moderator may edit another user's description" do
      user = confirmed_user_fixture()

      assert {:ok, %Ecto.Changeset{data: loaded}} =
               Users.edit_profile_description(actor(moderator_user_fixture()), user.slug)

      assert loaded.id == user.id
    end

    test "an unrelated user may not edit another user's description" do
      user = confirmed_user_fixture()

      assert Users.edit_profile_description(actor(confirmed_user_fixture()), user.slug) ==
               {:error, :unauthorized}
    end

    test "a banned actor is rejected before any authorization" do
      user = confirmed_user_fixture()

      assert Users.edit_profile_description(actor(user, ban: @ban), user.slug) ==
               {:error, :ban}
    end

    test "an actor without a fingerprint still gets the form" do
      user = confirmed_user_fixture()

      assert {:ok, _} = Users.edit_profile_description(actor(user, fingerprint: nil), user.slug)
    end

    test "an unknown slug is not-found before instance authorization" do
      assert Users.edit_profile_description(
               actor(moderator_user_fixture()),
               "no-such-user"
             ) ==
               {:error, :not_found}

      assert Users.edit_profile_description(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "update_profile_description/3" do
    test "the owner updates their description" do
      user = confirmed_user_fixture()

      assert {:ok, updated} =
               Users.update_profile_description(actor(user), user.slug, %{
                 "description" => "New bio text"
               })

      assert updated.id == user.id
      assert Users.fetch_user_for_worker!(user.id).description == "New bio text"
    end

    test "files one report when the profile becomes unapproved" do
      user = confirmed_user_fixture()
      rule_fixture(name: "Review")

      assert {:ok, _updated} =
               Users.update_profile_description(actor(user), user.slug, %{
                 "description" => "https://outside.example/profile"
               })

      assert Repo.aggregate(Report, :count) == 1

      assert {:ok, _updated} =
               Users.update_profile_description(actor(user), user.slug, %{
                 "description" => "https://another-outside.example/profile"
               })

      assert Repo.aggregate(Report, :count) == 1
    end

    test "a banned actor is rejected" do
      user = confirmed_user_fixture()

      assert Users.update_profile_description(actor(user, ban: @ban), user.slug, %{
               "description" => "New bio text"
             }) == {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized" do
      user = confirmed_user_fixture()

      assert Users.update_profile_description(actor(user, fingerprint: nil), user.slug, %{
               "description" => "New bio text"
             }) == {:error, :unauthorized}
    end

    test "an unrelated user may not update another user's description" do
      user = confirmed_user_fixture()

      assert Users.update_profile_description(actor(confirmed_user_fixture()), user.slug, %{
               "description" => "New bio text"
             }) == {:error, :unauthorized}
    end
  end

  describe "edit_profile_scratchpad/2" do
    test "a moderator may edit the scratchpad" do
      user = confirmed_user_fixture()

      assert {:ok, %Ecto.Changeset{data: loaded}} =
               Users.edit_profile_scratchpad(actor(moderator_user_fixture()), user.slug)

      assert loaded.id == user.id
    end

    test "an assistant may edit the scratchpad" do
      user = confirmed_user_fixture()

      assert {:ok, %Ecto.Changeset{data: loaded}} =
               Users.edit_profile_scratchpad(actor(assistant_user_fixture()), user.slug)

      assert loaded.id == user.id
    end

    test "a regular user may not edit the scratchpad" do
      user = confirmed_user_fixture()

      assert Users.edit_profile_scratchpad(actor(confirmed_user_fixture()), user.slug) ==
               {:error, :unauthorized}
    end

    test "a banned actor is rejected before the mod-note check" do
      user = confirmed_user_fixture()

      assert Users.edit_profile_scratchpad(
               actor(moderator_user_fixture(), ban: @ban),
               user.slug
             ) == {:error, :ban}
    end

    test "an actor without a fingerprint still gets the form" do
      user = confirmed_user_fixture()

      assert {:ok, _} =
               Users.edit_profile_scratchpad(
                 actor(moderator_user_fixture(), fingerprint: nil),
                 user.slug
               )
    end

    test "a permitted actor naming an unknown slug is not-found" do
      assert Users.edit_profile_scratchpad(
               actor(moderator_user_fixture()),
               "no-such-user"
             ) ==
               {:error, :not_found}
    end
  end

  describe "update_profile_scratchpad/3" do
    test "a moderator updates the scratchpad" do
      user = confirmed_user_fixture()

      assert {:ok, updated} =
               Users.update_profile_scratchpad(actor(moderator_user_fixture()), user.slug, %{
                 "scratchpad" => "Mod notes here"
               })

      assert updated.id == user.id
      assert Users.fetch_user_for_worker!(user.id).scratchpad == "Mod notes here"
    end

    test "a regular user may not update the scratchpad" do
      user = confirmed_user_fixture()

      assert Users.update_profile_scratchpad(actor(confirmed_user_fixture()), user.slug, %{
               "scratchpad" => "Mod notes here"
             }) == {:error, :unauthorized}
    end

    test "a banned actor is rejected" do
      user = confirmed_user_fixture()

      assert Users.update_profile_scratchpad(
               actor(moderator_user_fixture(), ban: @ban),
               user.slug,
               %{
                 "scratchpad" => "Mod notes here"
               }
             ) == {:error, :ban}
    end
  end

  describe "list_profile_aliases/2" do
    test "a moderator sees a user sharing only an IP under ip_matches" do
      subject = confirmed_user_fixture()
      alias_user = confirmed_user_fixture()
      user_ip_fixture(subject, "203.0.113.70")
      user_ip_fixture(alias_user, "203.0.113.70")

      assert {:ok, %AliasMatches{} = matches} =
               Users.list_profile_aliases(actor(moderator_user_fixture()), subject.slug)

      assert alias_user.id in Enum.map(matches.ip_matches, & &1.id)
      refute alias_user.id in Enum.map(matches.fp_matches, & &1.id)
      refute alias_user.id in Enum.map(matches.both_matches, & &1.id)
    end

    test "a moderator sees a user sharing only a fingerprint under fp_matches" do
      subject = confirmed_user_fixture()
      alias_user = confirmed_user_fixture()
      user_fingerprint_fixture(subject, "aliasfp70")
      user_fingerprint_fixture(alias_user, "aliasfp70")

      assert {:ok, %AliasMatches{} = matches} =
               Users.list_profile_aliases(actor(moderator_user_fixture()), subject.slug)

      assert alias_user.id in Enum.map(matches.fp_matches, & &1.id)
      refute alias_user.id in Enum.map(matches.ip_matches, & &1.id)
    end

    test "a moderator sees a user sharing both an IP and a fingerprint under both_matches" do
      subject = confirmed_user_fixture()
      alias_user = confirmed_user_fixture()
      user_ip_fixture(subject, "203.0.113.71")
      user_ip_fixture(alias_user, "203.0.113.71")
      user_fingerprint_fixture(subject, "aliasfp71")
      user_fingerprint_fixture(alias_user, "aliasfp71")

      assert {:ok, %AliasMatches{} = matches} =
               Users.list_profile_aliases(actor(moderator_user_fixture()), subject.slug)

      assert alias_user.id in Enum.map(matches.both_matches, & &1.id)
      refute alias_user.id in Enum.map(matches.ip_matches, & &1.id)
      refute alias_user.id in Enum.map(matches.fp_matches, & &1.id)
    end

    test "a regular user may not load alias matches" do
      assert Users.list_profile_aliases(
               actor(confirmed_user_fixture()),
               confirmed_user_fixture().slug
             ) ==
               {:error, :unauthorized}
    end

    test "an unknown slug is not-found before instance authorization" do
      assert Users.list_profile_aliases(actor(moderator_user_fixture()), "no-such-user") ==
               {:error, :not_found}

      assert Users.list_profile_aliases(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "staff_categories/0" do
    test "groups an admin under Administrators" do
      admin = staff_user("admin")

      categories = Users.staff_categories()
      assert admin.id in Enum.map(categories[:administrators], & &1.id)
    end

    test "groups a plain moderator under Moderators" do
      mod = staff_user("moderator")

      categories = Users.staff_categories()
      assert mod.id in Enum.map(categories[:moderators], & &1.id)
      refute mod.id in Enum.map(categories[:administrators], & &1.id)
    end

    test "groups a plain assistant under Assistants" do
      assistant = staff_user("assistant")

      categories = Users.staff_categories()
      assert assistant.id in Enum.map(categories[:assistants], & &1.id)
    end

    test "groups a Site Developer under Technical Team by secondary role" do
      dev = staff_user("moderator", secondary_role: "Site Developer")

      categories = Users.staff_categories()
      assert dev.id in Enum.map(categories[:developers], & &1.id)
      # A distinguishing secondary role takes the user out of Moderators.
      refute dev.id in Enum.map(categories[:moderators], & &1.id)
    end

    test "groups a Public Relations staffer under Public Relations" do
      pr = staff_user("moderator", secondary_role: "Public Relations")

      categories = Users.staff_categories()
      assert pr.id in Enum.map(categories[:public_relations], & &1.id)
    end

    test "shows a staff member who hides their default role with no distinguishing secondary role" do
      hidden = staff_user("moderator", hide_default_role: true)

      all_listed =
        Users.staff_categories()
        |> Enum.flat_map(fn {_category, users} -> Enum.map(users, & &1.id) end)

      assert hidden.id in all_listed
    end

    test "does not list ordinary users" do
      user = confirmed_user_fixture()

      all_listed =
        Users.staff_categories()
        |> Enum.flat_map(fn {_category, users} -> Enum.map(users, & &1.id) end)

      refute user.id in all_listed
    end
  end

  describe "edit_name/1" do
    test "returns a changeset for a user whose rename window is open" do
      user = renameable_user()

      assert {:ok, %Ecto.Changeset{data: loaded}} =
               Users.edit_name(actor(user))

      assert loaded.id == user.id
    end

    test "a banned actor is rejected before authorization" do
      user = confirmed_user_fixture()

      assert Users.edit_name(actor(user, ban: @ban)) == {:error, :ban}
    end

    test "an actor without a fingerprint still gets the form" do
      user = renameable_user()

      assert {:ok, _} = Users.edit_name(actor(user, fingerprint: nil))
    end

    test "a user who renamed within the window is unauthorized" do
      user = recently_renamed_user()

      assert Users.edit_name(actor(user)) == {:error, :unauthorized}
    end
  end

  describe "update_name/2" do
    test "renames the acting user and records the change in history" do
      user = renameable_user()
      old_name = user.name

      assert {:ok, updated} = Users.update_name(actor(user), %{"name" => "renamed_user_ok"})
      assert updated.name == "renamed_user_ok"
      assert Users.fetch_user_for_worker!(user.id).name == "renamed_user_ok"

      assert Repo.get_by(Philomena.UserNameChanges.UserNameChange,
               user_id: user.id,
               name: old_name
             )
    end

    test "a banned actor is rejected" do
      user = confirmed_user_fixture()

      assert Users.update_name(actor(user, ban: @ban), %{"name" => "renamed_user_ban"}) ==
               {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized" do
      user = confirmed_user_fixture()

      assert Users.update_name(actor(user, fingerprint: nil), %{"name" => "renamed_user_fp"}) ==
               {:error, :unauthorized}
    end

    test "a user whose rename window is closed is unauthorized" do
      user = recently_renamed_user()

      assert Users.update_name(actor(user), %{"name" => "renamed_user_window"}) ==
               {:error, :unauthorized}
    end

    test "a blank name is a rejected changeset" do
      user = renameable_user()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Users.update_name(actor(user), %{"name" => ""})

      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "a case variant of another user's name is a rejected changeset" do
      %{name: taken} = user_fixture(%{name: "TakenName#{System.unique_integer([:positive])}"})
      user = renameable_user()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Users.update_name(actor(user), %{"name" => String.upcase(taken)})

      assert %{name: ["has already been taken"]} = errors_on(changeset)

      stored = Users.fetch_user_for_worker!(user.id)
      assert stored.name == user.name
      assert stored.slug == user.slug

      refute Repo.get_by(Philomena.UserNameChanges.UserNameChange, user_id: user.id)
    end

    test "changing only the letter case of the user's own name succeeds" do
      name = "OwnName#{System.unique_integer([:positive])}"
      user = Users.fetch_user_for_worker!(confirmed_user_fixture(%{name: name}).id)
      recased = String.upcase(name)

      assert {:ok, %User{} = updated} = Users.update_name(actor(user), %{"name" => recased})
      assert updated.name == recased
      assert updated.slug == recased

      stored = Users.fetch_user_for_worker!(user.id)
      assert stored.name == recased
      assert stored.slug == recased

      assert Repo.get_by(Philomena.UserNameChanges.UserNameChange, user_id: user.id, name: name)
    end
  end

  describe "edit_avatar/1" do
    test "returns the avatar form changeset for a normal actor" do
      user = confirmed_user_fixture()

      assert {:ok, %Ecto.Changeset{data: loaded}} =
               Users.edit_avatar(actor(user))

      assert loaded.id == user.id
    end

    test "a banned actor is rejected" do
      user = confirmed_user_fixture()

      assert Users.edit_avatar(actor(user, ban: @ban)) == {:error, :ban}
    end

    test "an actor without a fingerprint still gets the form" do
      user = confirmed_user_fixture()

      assert {:ok, _} = Users.edit_avatar(actor(user, fingerprint: nil))
    end
  end

  describe "update_avatar/2 (actor)" do
    test "uploads the acting user's avatar" do
      user = confirmed_user_fixture()

      assert {:ok, updated} =
               Users.update_avatar(actor(user), media_png_upload())

      assert updated.avatar =~ ~r/\.png$/
      assert Users.fetch_user_for_worker!(user.id).avatar =~ ~r/\.png$/
    end

    test "a banned actor is rejected before analysis" do
      user = confirmed_user_fixture()

      assert Users.update_avatar(actor(user, ban: @ban), media_png_upload()) ==
               {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized before analysis" do
      user = confirmed_user_fixture()

      assert Users.update_avatar(actor(user, fingerprint: nil), media_png_upload()) ==
               {:error, :unauthorized}
    end

    test "the ban wins over a missing fingerprint" do
      user = confirmed_user_fixture()

      assert Users.update_avatar(
               actor(user, ban: @ban, fingerprint: nil),
               media_png_upload()
             ) == {:error, :ban}
    end

    test "a missing avatar file is a rejected changeset" do
      user = confirmed_user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Users.update_avatar(actor(user), nil)
    end
  end

  describe "delete_avatar/1 (actor)" do
    test "removes the acting user's avatar" do
      user = user_with_avatar_fixture()

      assert {:ok, updated} = Users.delete_avatar(actor(user))
      refute updated.avatar
      refute Users.fetch_user_for_worker!(user.id).avatar
    end

    test "a banned actor is rejected" do
      user = user_with_avatar_fixture()

      assert Users.delete_avatar(actor(user, ban: @ban)) == {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized" do
      user = user_with_avatar_fixture()

      assert Users.delete_avatar(actor(user, fingerprint: nil)) == {:error, :unauthorized}
    end
  end

  describe "edit_totp/1" do
    test "stores a fresh TOTP secret without enabling 2FA" do
      user = confirmed_user_fixture()
      refute user.encrypted_otp_secret

      assert {:ok, updated} = Users.edit_totp(user)
      assert updated.encrypted_otp_secret
      refute updated.otp_required_for_login
    end
  end

  describe "update_totp/2" do
    test "enables 2FA with a valid code, returning ten fresh backup codes" do
      {:ok, user} = Users.edit_totp(confirmed_user_fixture())

      assert {:ok, updated, backup_codes} =
               Users.update_totp(user, totp_params(valid_totp_code(user)))

      assert updated.otp_required_for_login
      assert length(backup_codes) == 10
      assert Enum.all?(backup_codes, &is_binary/1)
      # The persisted codes are the hashed form of the returned plaintext.
      assert length(Users.fetch_user_for_worker!(user.id).otp_backup_codes) == 10
    end

    test "disables 2FA and still returns ten fresh backup codes, clearing the stored ones" do
      user = totp_user_fixture()

      assert {:ok, updated, backup_codes} =
               Users.update_totp(user, totp_params(valid_totp_code(user)))

      refute updated.otp_required_for_login
      # Codes are regenerated even on disable, but the account keeps none.
      assert length(backup_codes) == 10
      assert Users.fetch_user_for_worker!(user.id).otp_backup_codes == []
      refute Users.fetch_user_for_worker!(user.id).encrypted_otp_secret
    end

    test "a wrong password is a rejected changeset" do
      {:ok, user} = Users.edit_totp(confirmed_user_fixture())

      assert {:error, %Ecto.Changeset{} = changeset} =
               Users.update_totp(user, %{
                 "user" => %{
                   "current_password" => "wrong password",
                   "twofactor_token" => valid_totp_code(user)
                 }
               })

      assert %{current_password: ["is invalid"]} = errors_on(changeset)
      refute Users.fetch_user_for_worker!(user.id).otp_required_for_login
    end

    test "an invalid second-factor code is a rejected changeset when enabling" do
      {:ok, user} = Users.edit_totp(confirmed_user_fixture())

      assert {:error, %Ecto.Changeset{} = changeset} =
               Users.update_totp(user, totp_params("not a code"))

      assert %{twofactor_token: ["Invalid token"]} = errors_on(changeset)
      refute Users.fetch_user_for_worker!(user.id).otp_required_for_login
    end
  end

  describe "create_session_totp/2" do
    test "accepts a valid live TOTP code" do
      user = totp_user_fixture()

      assert {:ok, %User{} = consumed} =
               Users.create_session_totp(user, %{
                 "user" => %{"twofactor_token" => valid_totp_code(user)}
               })

      assert consumed.consumed_timestep
    end

    test "accepts a backup code once, then rejects the same code" do
      {:ok, user} = Users.edit_totp(confirmed_user_fixture())

      {:ok, user, [backup_code | _rest]} =
        Users.update_totp(user, totp_params(valid_totp_code(user)))

      assert {:ok, %User{} = consumed} =
               Users.create_session_totp(user, %{
                 "user" => %{"twofactor_token" => backup_code}
               })

      # The consumed code is removed from the remaining set.
      assert length(consumed.otp_backup_codes) == 9

      assert {:error, %Ecto.Changeset{} = changeset} =
               Users.create_session_totp(consumed, %{
                 "user" => %{"twofactor_token" => backup_code}
               })

      assert %{twofactor_token: ["Invalid token"]} = errors_on(changeset)
    end

    test "rejects an invalid token" do
      user = totp_user_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Users.create_session_totp(user, %{
                 "user" => %{"twofactor_token" => "not a code"}
               })

      assert %{twofactor_token: ["Invalid token"]} = errors_on(changeset)
    end
  end

  describe "query_users/3" do
    setup do
      Search.clear_index!(User)
      :ok
    end

    test "an anonymous viewer is rejected before any search" do
      assert Users.query_users(actor(), %{}, @pagination) == {:error, :unauthorized}
    end

    test "a regular user is rejected" do
      assert Users.query_users(actor(confirmed_user_fixture()), %{}, @pagination) ==
               {:error, :unauthorized}
    end

    test "a moderator sees a user in the default view" do
      target = confirmed_user_fixture()
      SearchHelpers.reindex_all!(User)

      assert {:ok, page, _changeset} =
               Users.query_users(actor(moderator_user_fixture()), %{}, @pagination)

      assert target.id in Enum.map(page.entries, & &1.id)
    end

    test "an admin sees a user in the default view" do
      target = confirmed_user_fixture()
      SearchHelpers.reindex_all!(User)

      assert {:ok, page, _changeset} =
               Users.query_users(actor(admin_user_fixture()), %{}, @pagination)

      assert target.id in Enum.map(page.entries, & &1.id)
    end

    test "a blank query searches everything" do
      target = confirmed_user_fixture()
      SearchHelpers.reindex_all!(User)

      assert {:ok, page, _changeset} =
               Users.query_users(actor(admin_user_fixture()), %{"query" => ""}, @pagination)

      assert target.id in Enum.map(page.entries, & &1.id)
    end

    test "the query param filters by name" do
      target = confirmed_user_fixture(%{name: "search_target_needle"})
      _other = confirmed_user_fixture(%{name: "search_other_haystack"})
      SearchHelpers.reindex_all!(User)

      assert {:ok, page, _changeset} =
               Users.query_users(
                 actor(admin_user_fixture()),
                 %{"query" => "name:search_target_needle"},
                 @pagination
               )

      assert target.id in Enum.map(page.entries, & &1.id)
    end

    test "an unparsable query returns the parser's message string" do
      assert {:error, changeset} =
               Users.query_users(actor(admin_user_fixture()), %{"query" => "("}, @pagination)

      assert errors_on(changeset)[:query]
    end
  end

  describe "edit_user/2" do
    test "an admin loads the user with roles preloaded" do
      target = managed_target()
      role = Repo.insert!(%Role{name: "admin", resource_type: "Forum"})

      assert {:ok, %AdminUserForm{changeset: changeset, roles: roles}} =
               Users.edit_user(actor(admin_user_fixture()), target.slug)

      user = changeset.data

      assert user.id == target.id
      assert is_list(user.roles)
      assert changeset.data.id == target.id
      assert role.id in Enum.map(roles, & &1.id)
    end

    test "a plain moderator is rejected" do
      target = managed_target()

      assert Users.edit_user(actor(moderator_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "a User-admin role_map moderator is rejected" do
      target = managed_target()

      assert Users.edit_user(actor(user_admin_moderator()), target.slug) ==
               {:error, :unauthorized}
    end

    test "an anonymous actor is rejected" do
      target = managed_target()

      assert Users.edit_user(actor(), target.slug) == {:error, :unauthorized}
    end

    test "an unknown slug is not-found before instance authorization" do
      assert Users.edit_user(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}

      assert Users.edit_user(actor(moderator_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "update_user/3" do
    test "an admin updates the user and writes the update log" do
      target = managed_target()

      assert {:ok, updated} =
               Users.update_user(actor(admin_user_fixture()), target.slug, %{
                 "name" => target.name,
                 "email" => target.email,
                 "role" => "assistant"
               })

      assert updated.role == "assistant"
      assert Users.fetch_user_for_worker!(target.id).role == "assistant"

      log = last_moderation_log()
      assert log.type == "Admin.User:update"
      assert log.body == "Updated user details for #{target.name}"
      assert log.subject_path == Paths.profile_path(updated)
    end

    test "an invalid role is a rejected changeset whose data has roles preloaded" do
      target = managed_target()

      assert {:error, %AdminUserForm{changeset: changeset}} =
               Users.update_user(actor(admin_user_fixture()), target.slug, %{
                 "name" => target.name,
                 "email" => target.email,
                 "role" => "not-a-role"
               })

      assert is_list(changeset.data.roles)
      assert Users.fetch_user_for_worker!(target.id).role == "user"
    end

    test "a case variant of another user's name is a rejected changeset" do
      %{name: taken} = managed_target("TakenName#{System.unique_integer([:positive])}")
      target = managed_target()

      assert {:error, %AdminUserForm{changeset: changeset}} =
               Users.update_user(actor(admin_user_fixture()), target.slug, %{
                 "name" => String.downcase(taken),
                 "email" => target.email,
                 "role" => target.role
               })

      assert %{name: ["has already been taken"]} = errors_on(changeset)

      stored = Users.fetch_user_for_worker!(target.id)
      assert stored.name == target.name
      assert stored.slug == target.slug
    end

    test "assigns existing role IDs and rejects malformed or missing role IDs" do
      target = managed_target()
      role = Repo.insert!(%Role{name: "admin", resource_type: "Forum"})

      valid_params = %{
        "name" => target.name,
        "email" => target.email,
        "role" => "user",
        "roles" => ["", to_string(role.id), ""]
      }

      assert {:ok, updated} =
               Users.update_user(actor(admin_user_fixture()), target.slug, valid_params)

      assert Enum.map(updated.roles, & &1.id) == [role.id]

      for invalid_id <- ["not-an-id", "2147483647"] do
        assert {:error, %AdminUserForm{changeset: changeset}} =
                 Users.update_user(
                   actor(admin_user_fixture()),
                   target.slug,
                   %{valid_params | "roles" => [invalid_id]}
                 )

        assert %{roles: ["contains an invalid role"]} = errors_on(changeset)

        assert Enum.map(
                 Users.fetch_user_for_worker!(target.id)
                 |> Repo.preload(:roles)
                 |> Map.get(:roles),
                 & &1.id
               ) ==
                 [role.id]
      end
    end

    test "a plain moderator may not update a user" do
      target = managed_target()

      assert Users.update_user(actor(moderator_user_fixture()), target.slug, %{
               "name" => target.name,
               "email" => target.email,
               "role" => "assistant"
             }) == {:error, :unauthorized}
    end

    test "a User-admin role_map moderator may not update a user" do
      target = managed_target()

      assert Users.update_user(actor(user_admin_moderator()), target.slug, %{
               "name" => target.name,
               "email" => target.email,
               "role" => "assistant"
             }) == {:error, :unauthorized}
    end

    test "an admin naming an unknown slug gets not-found" do
      assert Users.update_user(actor(admin_user_fixture()), "no-such-user", %{}) ==
               {:error, :not_found}
    end
  end

  # The staff child-write functions share write-access checks and safe target
  # loading, then authorize their action against the real user. This matrix pins
  # the common boundary once; each action below pins its effect, log, and missing
  # target behavior.
  describe "staff user-management authorization gate" do
    test "a missing target is not-found before instance authorization" do
      assert Users.create_user_unlock(actor(), "no-such-user") == {:error, :not_found}
    end

    test "a regular user is rejected" do
      target = managed_target()

      assert Users.create_user_unlock(actor(confirmed_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "a plain moderator is rejected" do
      target = managed_target()

      assert Users.create_user_unlock(actor(moderator_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "a User-admin role_map moderator is rejected" do
      target = managed_target()

      assert Users.create_user_unlock(actor(user_admin_moderator()), target.slug) ==
               {:error, :unauthorized}
    end

    test "an admin is permitted" do
      target = managed_target()

      assert {:ok, _user} = Users.create_user_unlock(actor(admin_user_fixture()), target.slug)
    end
  end

  describe "create_user_activation/2" do
    test "an admin reactivates a deactivated user and logs it" do
      target = deactivated_user_fixture()

      assert {:ok, user} = Users.create_user_activation(actor(admin_user_fixture()), target.slug)
      refute user.deleted_at
      refute Users.fetch_user_for_worker!(target.id).deleted_at

      log = last_moderation_log()
      assert log.type == "Admin.User.Activation:create"
      assert log.body == "Reactivated #{target.name}"
      assert log.subject_path == Paths.profile_path(user)
    end

    test "a plain moderator is rejected" do
      target = deactivated_user_fixture()

      assert Users.create_user_activation(actor(moderator_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "an admin naming an unknown slug gets not-found" do
      assert Users.create_user_activation(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "delete_user_activation/2" do
    test "an admin deactivates a user, recording the actor, and logs it" do
      target = managed_target()
      admin = admin_user_fixture()

      assert {:ok, user} = Users.delete_user_activation(actor(admin), target.slug)
      assert user.deleted_at
      assert user.deleted_by_user_id == admin.id
      assert Users.fetch_user_for_worker!(target.id).deleted_at

      log = last_moderation_log()
      assert log.type == "Admin.User.Activation:delete"
      assert log.body == "Deactivated #{target.name}"
      assert log.subject_path == Paths.profile_path(user)
    end

    test "a plain moderator is rejected" do
      target = managed_target()

      assert Users.delete_user_activation(actor(moderator_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "an admin naming an unknown slug gets not-found" do
      assert Users.delete_user_activation(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "delete_user_api_key/2" do
    test "an admin resets the API token and logs it" do
      target = managed_target()
      old_token = target.authentication_token

      assert {:ok, user} = Users.delete_user_api_key(actor(admin_user_fixture()), target.slug)
      assert user.authentication_token != old_token

      assert Users.fetch_user_for_worker!(target.id).authentication_token ==
               user.authentication_token

      log = last_moderation_log()
      assert log.type == "Admin.User.ApiKey:delete"
      assert log.body == "Reset API key for #{target.name}"
      assert log.subject_path == Paths.profile_path(user)
    end

    test "a plain moderator is rejected" do
      target = managed_target()

      assert Users.delete_user_api_key(actor(moderator_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "an admin naming an unknown slug gets not-found" do
      assert Users.delete_user_api_key(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "delete_user_avatar/2" do
    test "an admin removes the avatar and logs it" do
      target =
        user_with_avatar_fixture(%{name: "avatar_target_#{System.unique_integer([:positive])}"})

      assert {:ok, user} = Users.delete_user_avatar(actor(admin_user_fixture()), target.slug)
      refute user.avatar
      refute Users.fetch_user_for_worker!(target.id).avatar

      log = last_moderation_log()
      assert log.type == "Admin.User.Avatar:delete"
      assert log.body == "Removed avatar for #{target.name}"
      assert log.subject_path == Paths.profile_path(user)
    end

    test "a plain moderator is rejected" do
      target = user_with_avatar_fixture()

      assert Users.delete_user_avatar(actor(moderator_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "an admin naming an unknown slug gets not-found" do
      assert Users.delete_user_avatar(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "delete_user_downvotes/2" do
    test "an admin starts the downvote wipe and logs it" do
      target = managed_target()

      assert {:ok, user} = Users.delete_user_downvotes(actor(admin_user_fixture()), target.slug)
      assert user.id == target.id

      log = last_moderation_log()
      assert log.type == "Admin.User.Downvote:delete"
      assert log.body == "Wiped downvotes for #{target.name}"
      assert log.subject_path == Paths.profile_path(user)
    end

    test "a plain moderator is rejected" do
      target = managed_target()

      assert Users.delete_user_downvotes(actor(moderator_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "an admin naming an unknown slug gets not-found" do
      assert Users.delete_user_downvotes(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "delete_user_votes/2" do
    test "an admin starts the vote and fave wipe and logs it" do
      target = managed_target()

      assert {:ok, user} = Users.delete_user_votes(actor(admin_user_fixture()), target.slug)
      assert user.id == target.id

      log = last_moderation_log()
      assert log.type == "Admin.User.Vote:delete"
      assert log.body == "Wiped votes and faves for #{target.name}"
      assert log.subject_path == Paths.profile_path(user)
    end

    test "a plain moderator is rejected" do
      target = managed_target()

      assert Users.delete_user_votes(actor(moderator_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "an admin naming an unknown slug gets not-found" do
      assert Users.delete_user_votes(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "create_user_wipe/2" do
    test "an admin queues the PII wipe and logs it" do
      target = managed_target()

      assert {:ok, user} = Users.create_user_wipe(actor(admin_user_fixture()), target.slug)
      assert user.id == target.id

      log = last_moderation_log()
      assert log.type == "Admin.User.Wipe:create"
      assert log.body == "Wiped PII for #{target.name}"
      assert log.subject_path == Paths.profile_path(user)
    end

    test "a plain moderator is rejected" do
      target = managed_target()

      assert Users.create_user_wipe(actor(moderator_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "an admin naming an unknown slug gets not-found" do
      assert Users.create_user_wipe(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "create_user_unlock/2" do
    test "an admin unlocks a locked user and logs it" do
      target = locked_user_fixture(%{name: "unlock_target_#{System.unique_integer([:positive])}"})

      assert {:ok, user} = Users.create_user_unlock(actor(admin_user_fixture()), target.slug)
      refute user.locked_at
      refute Users.fetch_user_for_worker!(target.id).locked_at

      log = last_moderation_log()
      assert log.type == "Admin.User.Unlock:create"
      assert log.body == "Unlocked #{target.name}"
      assert log.subject_path == Paths.profile_path(user)
    end

    test "a plain moderator is rejected" do
      target = locked_user_fixture()

      assert Users.create_user_unlock(actor(moderator_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "an admin naming an unknown slug gets not-found" do
      assert Users.create_user_unlock(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "create_user_verification/2" do
    test "an admin grants verification and logs it" do
      target = managed_target()

      assert {:ok, user} =
               Users.create_user_verification(actor(admin_user_fixture()), target.slug)

      assert user.verified
      assert Users.fetch_user_for_worker!(target.id).verified

      log = last_moderation_log()
      assert log.type == "Admin.User.Verification:create"
      assert log.body == "Granted verification to #{target.name}"
      assert log.subject_path == Paths.profile_path(user)
    end

    test "a plain moderator is rejected" do
      target = managed_target()

      assert Users.create_user_verification(actor(moderator_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "an admin naming an unknown slug gets not-found" do
      assert Users.create_user_verification(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "delete_user_verification/2" do
    test "an admin revokes verification and logs it" do
      target =
        verified_user_fixture(%{name: "unverify_target_#{System.unique_integer([:positive])}"})

      assert {:ok, user} =
               Users.delete_user_verification(actor(admin_user_fixture()), target.slug)

      refute user.verified
      refute Users.fetch_user_for_worker!(target.id).verified

      log = last_moderation_log()
      assert log.type == "Admin.User.Verification:delete"
      assert log.body == "Revoked verification from #{target.name}"
      assert log.subject_path == Paths.profile_path(user)
    end

    test "a plain moderator is rejected" do
      target = verified_user_fixture()

      assert Users.delete_user_verification(actor(moderator_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "an admin naming an unknown slug gets not-found" do
      assert Users.delete_user_verification(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "new_user_force_filter/2" do
    test "an admin loads the target user" do
      target = managed_target()

      assert {:ok, %Ecto.Changeset{data: user}} =
               Users.new_user_force_filter(actor(admin_user_fixture()), target.slug)

      assert user.id == target.id
    end

    test "a plain moderator is rejected" do
      target = managed_target()

      assert Users.new_user_force_filter(actor(moderator_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "an admin naming an unknown slug gets not-found" do
      assert Users.new_user_force_filter(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "create_user_force_filter/3" do
    test "an admin forces a filter and logs it" do
      target = managed_target()
      filter = filter_fixture(confirmed_user_fixture())

      assert {:ok, user} =
               Users.create_user_force_filter(actor(admin_user_fixture()), target.slug, %{
                 "forced_filter_id" => filter.id
               })

      assert user.forced_filter_id == filter.id
      assert Users.fetch_user_for_worker!(target.id).forced_filter_id == filter.id

      log = last_moderation_log()
      assert log.type == "Admin.User.ForceFilter:create"
      assert log.body == "Forced filter #{filter.id} for #{target.name}"
      assert log.subject_path == Paths.profile_path(user)
    end

    test "a nonexistent forced_filter_id returns the typed form error" do
      target = managed_target()

      assert {:error, %Ecto.Changeset{data: user} = changeset} =
               Users.create_user_force_filter(actor(admin_user_fixture()), target.slug, %{
                 "forced_filter_id" => 2_000_000_000
               })

      assert user.id == target.id
      assert %{forced_filter_id: ["does not exist"]} = errors_on(changeset)
      refute Users.fetch_user_for_worker!(target.id).forced_filter_id
    end

    test "a plain moderator is rejected before the filter is applied" do
      target = managed_target()
      filter = filter_fixture(confirmed_user_fixture())

      assert Users.create_user_force_filter(actor(moderator_user_fixture()), target.slug, %{
               "forced_filter_id" => filter.id
             }) == {:error, :unauthorized}
    end

    test "an admin naming an unknown slug gets not-found" do
      assert Users.create_user_force_filter(actor(admin_user_fixture()), "no-such-user", %{}) ==
               {:error, :not_found}
    end
  end

  describe "delete_user_force_filter/2" do
    test "an admin clears a forced filter and logs it" do
      target = managed_target()
      filter = filter_fixture(confirmed_user_fixture())

      target
      |> User.force_filter_changeset(%{"forced_filter_id" => filter.id})
      |> Repo.update!()

      assert {:ok, user} =
               Users.delete_user_force_filter(actor(admin_user_fixture()), target.slug)

      refute user.forced_filter_id
      refute Users.fetch_user_for_worker!(target.id).forced_filter_id

      log = last_moderation_log()
      assert log.type == "Admin.User.ForceFilter:delete"
      assert log.body == "Removed forced filter for #{target.name}"
      assert log.subject_path == Paths.profile_path(user)
    end

    test "a plain moderator is rejected" do
      target = managed_target()

      assert Users.delete_user_force_filter(actor(moderator_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "an admin naming an unknown slug gets not-found" do
      assert Users.delete_user_force_filter(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "new_user_erase/2" do
    test "an admin loads an ordinary unverified user with roles preloaded" do
      target = managed_target()

      assert {:ok, user} = Users.new_user_erase(actor(admin_user_fixture()), target.slug)
      assert user.id == target.id
      assert is_list(user.roles)
    end

    test "a missing target is not-found before instance authorization" do
      assert Users.new_user_erase(actor(moderator_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end

    test "an unknown slug is not-found" do
      assert Users.new_user_erase(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end

    test "a privileged target is rejected" do
      target = assistant_user_fixture()

      assert {:error, {:privileged, user}} =
               Users.new_user_erase(actor(admin_user_fixture()), target.slug)

      assert user.id == target.id
    end

    test "a verified target is rejected" do
      target = verified_user_fixture()

      assert {:error, {:verified, user}} =
               Users.new_user_erase(actor(admin_user_fixture()), target.slug)

      assert user.id == target.id
    end
  end

  describe "create_user_erase/2" do
    test "an admin erases the user, renaming and deactivating the account, and logs it" do
      target = managed_target()
      original_name = target.name

      assert {:ok, erased} = Users.create_user_erase(actor(admin_user_fixture()), target.slug)
      assert erased.name =~ ~r/^deactivated_/
      assert erased.name != original_name
      assert erased.deleted_at

      reloaded = Users.fetch_user_for_worker!(target.id)
      assert reloaded.name == erased.name
      assert reloaded.deleted_at

      # The log body names the original account; the subject path points at the
      # renamed account.
      log = last_moderation_log()
      assert log.type == "Admin.User.Erase:create"
      assert log.body == "Erased #{original_name}"
      assert log.subject_path == Paths.profile_path(erased)
    end

    test "an unauthorized actor is rejected" do
      target = managed_target()

      assert Users.create_user_erase(actor(moderator_user_fixture()), target.slug) ==
               {:error, :unauthorized}
    end

    test "an unknown slug is not-found" do
      assert Users.create_user_erase(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end

    test "a privileged target is rejected without erasing" do
      target = assistant_user_fixture()

      assert {:error, {:privileged, _user}} =
               Users.create_user_erase(actor(admin_user_fixture()), target.slug)

      assert Users.fetch_user_for_worker!(target.id).role == "assistant"
    end

    test "a verified target is rejected without erasing" do
      target = verified_user_fixture()

      assert {:error, {:verified, _user}} =
               Users.create_user_erase(actor(admin_user_fixture()), target.slug)

      refute Users.fetch_user_for_worker!(target.id).deleted_at
    end
  end
end
