defmodule PhilomenaWeb.Profile.ScratchpadControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures

  alias Philomena.Repo
  alias Philomena.Users.User

  describe "GET /profiles/:profile_id/scratchpad/edit" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{user}/scratchpad/edit")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      other = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{other}/scratchpad/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the form for a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()

      response = html_response(get(conn, ~p"/profiles/#{other}/scratchpad/edit"), 200)

      assert response =~ "Editing Moderation Scratchpad - Derpibooru"
      assert response =~ "Updating Moderation Scratchpad"
    end

    test "redirects with the not-found flash for an unknown profile slug", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/profiles/#{"nonexistent-slug"}/scratchpad/edit")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    test "renders the form for a moderator without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()

      conn = get(without_fingerprint(conn), ~p"/profiles/#{other}/scratchpad/edit")

      assert html_response(conn, 200) =~ "Editing Moderation Scratchpad - Derpibooru"
    end
  end

  describe "PATCH /profiles/:profile_id/scratchpad" do
    test "updates the scratchpad and redirects to the profile", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()

      conn =
        patch(conn, ~p"/profiles/#{other}/scratchpad", %{
          "user" => %{"scratchpad" => "Keep an eye on this one."}
        })

      assert redirected_to(conn) == ~p"/profiles/#{other}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Moderation scratchpad successfully updated."

      assert Repo.get!(User, other.id).scratchpad == "Keep an eye on this one."
    end

    test "PUT also updates the scratchpad", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()

      conn =
        put(conn, ~p"/profiles/#{other}/scratchpad", %{
          "user" => %{"scratchpad" => "via PUT"}
        })

      assert redirected_to(conn) == ~p"/profiles/#{other}"
      assert Repo.get!(User, other.id).scratchpad == "via PUT"
    end

    # NOTE: `scratchpad_changeset` only casts `:scratchpad` with no validation,
    # so a blank value is a success - there is no reachable `{:error, changeset}`
    # re-render branch. `cast/3` treats "" as empty and stores `nil`.
    test "storing a blank scratchpad succeeds and stores nil", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()

      conn =
        patch(conn, ~p"/profiles/#{other}/scratchpad", %{"user" => %{"scratchpad" => ""}})

      assert redirected_to(conn) == ~p"/profiles/#{other}"
      assert Repo.get!(User, other.id).scratchpad == nil
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      other = confirmed_user_fixture()

      conn =
        patch(conn, ~p"/profiles/#{other}/scratchpad", %{"user" => %{"scratchpad" => "x"}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "redirects with the not-found flash for an unknown profile slug", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/profiles/#{"nonexistent-slug"}/scratchpad", %{
          "user" => %{"scratchpad" => "x"}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()

      conn =
        patch(without_fingerprint(conn), ~p"/profiles/#{other}/scratchpad", %{
          "user" => %{"scratchpad" => "Keep an eye on this one."}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get!(User, other.id).scratchpad
    end
  end
end
