defmodule PhilomenaWeb.Admin.UserControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  # The index action reads the User OpenSearch index, so this module is
  # search-backed.

  @moduletag :search

  import Philomena.UsersFixtures

  alias Philomena.Roles.Role
  alias Philomena.Users.User
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers
  alias Philomena.Repo

  setup do
    Search.clear_index!(User)
    :ok
  end

  describe "GET /admin/users authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/users")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/users")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows a moderator, who may add artist links", %{conn: conn} do
      target = confirmed_user_fixture()
      SearchHelpers.reindex_all!(User)
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/admin/users")

      assert html_response(conn, 200) =~ ~p"/profiles/#{target}/artist_links/new"
    end

    test "allows an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/users")
      assert html_response(conn, 200) =~ "Users"
    end
  end

  describe "GET /admin/users (index) content" do
    setup [:register_and_log_in_admin]

    test "an empty uq parameter uses the default user query", %{conn: conn} do
      target = confirmed_user_fixture()
      SearchHelpers.reindex_all!(User)

      conn = get(conn, ~p"/admin/users?uq=")

      assert html_response(conn, 200) =~ target.name
    end

    test "lists a user in the default (\"*\") view", %{conn: conn} do
      target = confirmed_user_fixture()
      SearchHelpers.reindex_all!(User)

      conn = get(conn, ~p"/admin/users")
      response = html_response(conn, 200)
      assert response =~ "Admin - Users - Derpibooru"
      assert response =~ target.name
    end

    test "filters by user", %{conn: conn} do
      target = confirmed_user_fixture()
      SearchHelpers.reindex_all!(User)

      conn = get(conn, ~p"/admin/users?#{[uq: [query: "name:#{target.name}"]]}")
      response = html_response(conn, 200)
      assert response =~ target.name
    end

    # NOTE: an unparsable query takes the error branch - the index re-renders
    # (200) with a query-parse error message and an empty user list.
    test "renders the parse-error branch for an invalid query", %{conn: conn} do
      conn = get(conn, ~p"/admin/users?#{[uq: [query: "("]]}")
      response = html_response(conn, 200)
      assert response =~ "Imbalanced parentheses."
    end
  end

  describe "GET /admin/users/:id/edit (edit)" do
    setup [:register_and_log_in_admin]

    test "renders the edit form", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = get(conn, ~p"/admin/users/#{target.slug}/edit")
      response = html_response(conn, 200)
      assert response =~ "Editing user"
      assert response =~ target.name
    end

    # NOTE: id_field is "slug" (a string column), so an unknown slug is a
    # not-found redirect (no CastError), and there is no non-integer shape.
    test "redirects for an unknown slug", %{conn: conn} do
      conn = get(conn, ~p"/admin/users/no-such-user/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the edit form without a fingerprint", %{conn: conn} do
      target = confirmed_user_fixture()

      conn = get(without_fingerprint(conn), ~p"/admin/users/#{target.slug}/edit")

      assert html_response(conn, 200) =~ "Editing user"
    end
  end

  describe "GET /admin/users/:id/edit (edit) authorization" do
    # NOTE: index is open to moderators, but :edit/:update have no plain-moderator
    # rule - only admins (or a User-moderator role_map grant) can edit a user.
    test "rejects a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/users/#{target.slug}/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "PATCH /admin/users/:id (update)" do
    setup [:register_and_log_in_admin]

    test "updates the user and redirects to their profile", %{conn: conn} do
      target = confirmed_user_fixture()
      role = Repo.insert!(%Role{name: "admin", resource_type: "Forum"})

      # Each role checkbox group submits a blank sentinel, as the edit form does.
      conn =
        patch(conn, ~p"/admin/users/#{target.slug}", %{
          "user" => %{
            "name" => target.name,
            "email" => target.email,
            "role" => "assistant",
            "roles" => ["", to_string(role.id), "", ""]
          }
        })

      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "successfully updated"

      updated = User |> Repo.get(target.id) |> Repo.preload(:roles)
      assert updated.role == "assistant"
      assert Enum.map(updated.roles, & &1.id) == [role.id]
    end

    test "shows the error for an unknown role id", %{conn: conn} do
      target = confirmed_user_fixture()

      conn =
        patch(conn, ~p"/admin/users/#{target.slug}", %{
          "user" => %{
            "name" => target.name,
            "email" => target.email,
            "role" => "user",
            "roles" => ["", "not-an-id"]
          }
        })

      assert html_response(conn, 200) =~ "contains an invalid role"
    end

    # NOTE: unlike the admin user-ban create branch, the update error branch
    # re-renders edit.html cleanly (200) - @user is set by the :update
    # load_and_authorize plug, so the form template's assign is available.
    test "re-renders the form on an invalid role", %{conn: conn} do
      target = confirmed_user_fixture()

      conn =
        patch(conn, ~p"/admin/users/#{target.slug}", %{
          "user" => %{
            "name" => target.name,
            "email" => target.email,
            "role" => "not-a-role"
          }
        })

      response = html_response(conn, 200)
      assert response =~ "Editing user"
      assert Repo.get(User, target.id).role == "user"
    end

    test "rejects a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/users/#{target.slug}", %{
          "user" => %{"name" => target.name, "email" => target.email, "role" => "assistant"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      target = confirmed_user_fixture()

      conn =
        patch(without_fingerprint(conn), ~p"/admin/users/#{target.slug}", %{
          "user" => %{"name" => target.name, "email" => target.email, "role" => "assistant"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(User, target.id).role == target.role
    end
  end

  describe "PUT /admin/users/:id (update)" do
    setup [:register_and_log_in_admin]

    test "updates the user via PUT as well", %{conn: conn} do
      target = confirmed_user_fixture()

      conn =
        put(conn, ~p"/admin/users/#{target.slug}", %{
          "user" => %{
            "name" => target.name,
            "email" => target.email,
            "role" => "moderator"
          }
        })

      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Repo.get(User, target.id).role == "moderator"
    end
  end
end
