defmodule PhilomenaWeb.Profile.DescriptionControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures

  alias Philomena.Repo
  alias Philomena.Users.User

  describe "GET /profiles/:profile_id/description/edit" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{user}/description/edit")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "renders the form for the profile's owner", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      response = html_response(get(conn, ~p"/profiles/#{user}/description/edit"), 200)

      assert response =~ "Editing Profile Description - Derpibooru"
      assert response =~ "Updating Profile Description"
    end

    test "renders the form for a moderator on another profile", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()

      assert html_response(get(conn, ~p"/profiles/#{other}/description/edit"), 200) =~
               "Editing Profile Description - Derpibooru"
    end

    test "redirects another user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      other = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{other}/description/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the form for the owner without a fingerprint", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/profiles/#{user}/description/edit")

      assert html_response(conn, 200) =~ "Editing Profile Description - Derpibooru"
    end
  end

  describe "PATCH /profiles/:profile_id/description" do
    test "updates the description and redirects to the profile", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        patch(conn, ~p"/profiles/#{user}/description", %{
          "user" => %{"description" => "My updated bio", "personal_title" => "Artist"}
        })

      assert redirected_to(conn) == ~p"/profiles/#{user}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Description successfully updated."

      reloaded = Repo.get!(User, user.id)
      assert reloaded.description == "My updated bio"
      assert reloaded.personal_title == "Artist"
    end

    test "with a reserved personal title re-renders the form", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        patch(conn, ~p"/profiles/#{user}/description", %{
          "user" => %{"description" => "Bio", "personal_title" => "Site Admin"}
        })

      # NOTE: failure re-renders edit.html without the :title assign
      response = html_response(conn, 200)
      assert response =~ "Updating Profile Description"
      assert response =~ "Oops, something went wrong"
      refute Repo.get!(User, user.id).personal_title
    end

    test "redirects another user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      other = confirmed_user_fixture()

      conn =
        patch(conn, ~p"/profiles/#{other}/description", %{
          "user" => %{"description" => "Defaced"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get!(User, other.id).description == other.description
    end

    test "redirects banned users with the ban flash", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_banned_user(%{conn: conn})

      conn = patch(conn, ~p"/profiles/#{user}/description", %{"user" => %{}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        patch(without_fingerprint(conn), ~p"/profiles/#{user}/description", %{
          "user" => %{"description" => "My updated bio"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get!(User, user.id).description == user.description
    end
  end
end
