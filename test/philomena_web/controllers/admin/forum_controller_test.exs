defmodule PhilomenaWeb.Admin.ForumControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures

  alias Philomena.Forums.Forum
  alias Philomena.Repo

  describe "GET /admin/forums (index) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/forums")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/forums")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/forums")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: Unlike badges and adverts, the Forum ability is `can? :edit, Forum`,
    # granted ONLY to admins (`role: "admin"`) - there is no role_map
    # ("Forum" => ...) grant anywhere in the ability rules. A
    # "Forum"-resource_type role_map entry therefore grants nothing, so the
    # moderator is still rejected.
    test "rejects a moderator with a Forum role_map entry", %{conn: conn} do
      conn = log_in_role_moderator(conn, "Forum")
      conn = get(conn, ~p"/admin/forums")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows an admin", %{conn: conn} do
      _forum = forum_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/forums")
      assert html_response(conn, 200) =~ "Listing Forums"
    end
  end

  describe "GET /admin/forums (index) content" do
    setup [:register_and_log_in_admin]

    test "lists an existing forum", %{conn: conn} do
      forum = forum_fixture()
      conn = get(conn, ~p"/admin/forums")
      response = html_response(conn, 200)
      assert response =~ "Admin - Forums - Derpibooru"
      assert response =~ forum.name
    end

    # NOTE: the empty index now renders 200 rather than raising BadMapError; the
    # empty ForumListPlug assign is handled instead of being probed with
    # Enum.at(resources, 0).__struct__.
    test "renders the empty index", %{conn: conn} do
      conn = get(conn, ~p"/admin/forums")

      response = html_response(conn, 200)
      assert response =~ "Admin - Forums - Derpibooru"
      assert response =~ "Listing Forums"
    end
  end

  describe "GET /admin/forums/new" do
    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/forums/new")
      assert redirected_to(conn) == "/"
    end

    test "renders the form for an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/forums/new")
      response = html_response(conn, 200)
      assert response =~ "New Forum - Derpibooru"
      assert response =~ "New Forum"
    end

    test "renders the form for an admin without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(without_fingerprint(conn), ~p"/admin/forums/new")

      assert html_response(conn, 200) =~ "New Forum - Derpibooru"
    end
  end

  describe "POST /admin/forums (create)" do
    test "gives a banned admin the ban response", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_admin(%{conn: conn})

      conn =
        post(conn, ~p"/admin/forums", %{
          "forum" => %{
            "name" => "Banned Forum",
            "short_name" => "bannedforum",
            "description" => "nope",
            "access_level" => "normal"
          }
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You are currently banned."
      refute Repo.get_by(Forum, short_name: "bannedforum")
    end

    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/admin/forums", %{
          "forum" => %{
            "name" => "Nope",
            "short_name" => "nope",
            "description" => "nope",
            "access_level" => "normal"
          }
        })

      assert redirected_to(conn) == "/"
      refute Repo.get_by(Forum, short_name: "nope")
    end

    test "creates a forum as an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        post(conn, ~p"/admin/forums", %{
          "forum" => %{
            "name" => "Created Forum",
            "short_name" => "createdforum",
            "description" => "A newly created forum",
            "access_level" => "normal"
          }
        })

      assert redirected_to(conn) == ~p"/admin/forums"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Forum created successfully."
      assert Repo.get_by(Forum, short_name: "createdforum")
    end

    test "re-renders the form on a validation failure", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        post(conn, ~p"/admin/forums", %{
          "forum" => %{
            "name" => "",
            "short_name" => "invalidforum",
            "description" => "missing name",
            "access_level" => "normal"
          }
        })

      assert html_response(conn, 200) =~ "New Forum"
      refute Repo.get_by(Forum, short_name: "invalidforum")
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        post(without_fingerprint(conn), ~p"/admin/forums", %{
          "forum" => %{
            "name" => "Fingerprintless Forum",
            "short_name" => "fingerprintless",
            "description" => "A newly created forum",
            "access_level" => "normal"
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get_by(Forum, short_name: "fingerprintless")
    end
  end

  describe "GET /admin/forums/:id/edit" do
    test "rejects a plain moderator", %{conn: conn} do
      forum = forum_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/forums/#{forum}/edit")
      assert redirected_to(conn) == "/"
    end

    test "renders the edit form for an admin", %{conn: conn} do
      forum = forum_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/forums/#{forum}/edit")
      response = html_response(conn, 200)
      assert response =~ "Editing Forum - Derpibooru"
      assert response =~ "Edit Forum"
    end

    # NOTE: Forums are loaded by `short_name` (id_field), a string column, so
    # an unknown/non-integer short name never casts - it just misses (no
    # Ecto.Query.CastError, unlike the integer-id badge/advert routes).
    # The context authorizes the loaded forum (nil for a missing short name),
    # the admin is authorized on the nil load, so :edit redirects with the
    # not-found flash.
    test "redirects with a not-found flash on an unknown short_name for :edit", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/forums/does-not-exist/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the edit form for an admin without a fingerprint", %{conn: conn} do
      forum = forum_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(without_fingerprint(conn), ~p"/admin/forums/#{forum}/edit")

      assert html_response(conn, 200) =~ "Editing Forum - Derpibooru"
    end
  end

  describe "PATCH /admin/forums/:id (update)" do
    test "rejects a plain moderator", %{conn: conn} do
      forum = forum_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = patch(conn, ~p"/admin/forums/#{forum}", %{"forum" => %{"name" => "changed"}})
      assert redirected_to(conn) == "/"
    end

    test "updates the forum as an admin", %{conn: conn} do
      forum = forum_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/forums/#{forum}", %{"forum" => %{"name" => "Renamed Forum"}})

      assert redirected_to(conn) == ~p"/admin/forums"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Forum updated successfully."
      assert Repo.get(Forum, forum.id).name == "Renamed Forum"
    end

    test "re-renders the edit form on a validation failure", %{conn: conn} do
      forum = forum_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = patch(conn, ~p"/admin/forums/#{forum}", %{"forum" => %{"name" => ""}})

      assert html_response(conn, 200) =~ "Edit Forum"
      assert Repo.get(Forum, forum.id).name == "Test Forum"
    end

    # NOTE: the context authorizes the loaded forum on :update; a missing short
    # name loads nil, the admin is authorized on it, so an unknown short name
    # redirects with the not-found flash (like :edit above).
    test "redirects with a not-found flash on an unknown short_name for :update", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = patch(conn, ~p"/admin/forums/does-not-exist", %{"forum" => %{"name" => "x"}})
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      forum = forum_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        patch(without_fingerprint(conn), ~p"/admin/forums/#{forum}", %{
          "forum" => %{"name" => "Renamed Forum"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(Forum, forum.id).name == forum.name
    end
  end

  describe "PUT /admin/forums/:id (update)" do
    test "updates the forum as an admin", %{conn: conn} do
      forum = forum_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = put(conn, ~p"/admin/forums/#{forum}", %{"forum" => %{"name" => "Put Renamed"}})

      assert redirected_to(conn) == ~p"/admin/forums"
      assert Repo.get(Forum, forum.id).name == "Put Renamed"
    end
  end
end
