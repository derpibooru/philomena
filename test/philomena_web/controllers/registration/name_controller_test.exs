defmodule PhilomenaWeb.Registration.NameControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures

  alias Philomena.Users
  alias Philomena.UserNameChanges.UserNameChange
  alias Philomena.Repo
  alias Phoenix.Flash

  describe "GET /registrations/name/edit" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/registrations/name/edit")
      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "renders the rename form", %{conn: conn} do
      # A fresh user's last_renamed_at defaults to 1970, so renaming is
      # allowed immediately after registration.
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/registrations/name/edit")
      assert html_response(conn, 200) =~ "Editing Name - Derpibooru"
    end

    test "rejects a user renamed within the last 90 days", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      user
      |> Ecto.Changeset.change(last_renamed_at: DateTime.utc_now(:second))
      |> Repo.update!()

      conn = get(conn, ~p"/registrations/name/edit")
      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end

    test "redirects banned users to the referrer with a flash", %{conn: conn} do
      user = banned_user_fixture()
      conn = conn |> log_in_user(user) |> get(~p"/registrations/name/edit")
      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :error) =~ "You are currently banned."
    end

    test "renders the rename form without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/registrations/name/edit")

      assert html_response(conn, 200) =~ "Editing Name - Derpibooru"
    end
  end

  describe "PATCH /registrations/name" do
    setup :register_and_log_in_user

    test "renames the user and records the change", %{conn: conn, user: user} do
      new_name = "renamed_#{System.unique_integer([:positive])}"

      conn = patch(conn, ~p"/registrations/name", %{"user" => %{"name" => new_name}})

      updated = Users.fetch_user_for_worker!(user.id)
      assert updated.name == new_name
      assert redirected_to(conn) == ~p"/profiles/#{updated}"
      assert Flash.get(conn.assigns.flash, :info) =~ "Name successfully updated."

      # The old name is kept as a name-change row and the rename window closes.
      assert Repo.get_by!(UserNameChange, user_id: user.id).name == user.name
      assert updated.last_renamed_at
    end

    test "re-renders on a validation failure", %{conn: conn, user: user} do
      too_long = String.duplicate("a", 51)
      conn = patch(conn, ~p"/registrations/name", %{"user" => %{"name" => too_long}})

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      assert Users.fetch_user_for_worker!(user.id).name == user.name
    end

    test "re-renders on an empty name", %{conn: conn, user: user} do
      # NOTE: validate_name now guards nil before String.trim/1, so an empty
      # name re-renders (200) with a "can't be blank" error instead of crashing.
      conn = patch(conn, ~p"/registrations/name", %{"user" => %{"name" => ""}})

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      assert Users.fetch_user_for_worker!(user.id).name == user.name
    end

    test "rejects a second rename within the window", %{conn: conn, user: user} do
      user
      |> Ecto.Changeset.change(last_renamed_at: DateTime.utc_now(:second))
      |> Repo.update!()

      conn = patch(conn, ~p"/registrations/name", %{"user" => %{"name" => "another_name"}})
      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
      assert Users.fetch_user_for_worker!(user.id).name == user.name
    end

    test "redirects anonymous users to the login page" do
      conn = build_conn()
      conn = patch(conn, ~p"/registrations/name", %{"user" => %{"name" => "nobody"}})
      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{
      conn: conn,
      user: user
    } do
      conn =
        patch(without_fingerprint(conn), ~p"/registrations/name", %{
          "user" => %{"name" => "renamed_#{System.unique_integer([:positive])}"}
        })

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Users.fetch_user_for_worker!(user.id).name == user.name
    end
  end

  describe "PUT /registrations/name" do
    setup :register_and_log_in_user

    test "behaves like PATCH", %{conn: conn, user: user} do
      new_name = "renamed_#{System.unique_integer([:positive])}"

      conn = put(conn, ~p"/registrations/name", %{"user" => %{"name" => new_name}})

      updated = Users.fetch_user_for_worker!(user.id)
      assert updated.name == new_name
      assert redirected_to(conn) == ~p"/profiles/#{updated}"
    end
  end
end
