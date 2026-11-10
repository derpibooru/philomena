defmodule PhilomenaWeb.PageControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # The read-only actions (:index, :show) and the staff-facing write
  # actions (:new, :create, :edit, :update) are covered here.

  import Philomena.StaticPagesFixtures
  import Philomena.UsersFixtures
  import Ecto.Query, only: [from: 2]

  alias Philomena.StaticPages.StaticPage
  alias Philomena.StaticPages.Version
  alias Philomena.Repo

  # Static pages are authorized against StaticPage, which only admins and
  # moderators with the "StaticPage" role_map grant can act on. Both the
  # write routes and the :index route also sit in the
  # require_authenticated_user scope, so anonymous users are bounced to the
  # login page before authorization runs.

  defp valid_page_params(extra \\ %{}) do
    unique = System.unique_integer([:positive])

    Enum.into(extra, %{
      "title" => "Created Page ##{unique}",
      "slug" => "created-page-#{unique}",
      "body" => "Created page *body*."
    })
  end

  describe "GET /pages" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      # NOTE: the pages index sits in the require_authenticated_user scope,
      # so anonymous users are sent to the login page rather than turned
      # away by authorization.
      conn = get(conn, ~p"/pages")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "You must log in to access this page."
    end

    test "redirects to / for regular users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      # NOTE: the context authorizes :index against the StaticPage module, which
      # only staff ability rules match - the pages index is staff-only even
      # though individual pages are public.
      conn = get(conn, ~p"/pages")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end

    test "redirects to / for a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/pages")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end

    test "renders the page list for a StaticPage-role moderator", %{conn: conn} do
      conn = log_in_role_moderator(conn, "StaticPage")
      page = static_page_fixture(user_fixture(), %{title: "Test Page Title"})

      conn = get(conn, ~p"/pages")
      response = html_response(conn, 200)

      assert response =~ "Pages - Derpibooru"
      assert response =~ "Test Page Title"
      assert response =~ ~p"/pages/#{page}"
    end

    test "renders the page list for admins", %{conn: conn} do
      %{conn: conn, user: admin} = register_and_log_in_admin(%{conn: conn})
      page = static_page_fixture(admin, %{title: "Test Page Title"})

      conn = get(conn, ~p"/pages")
      response = html_response(conn, 200)

      assert response =~ "Pages - Derpibooru"
      assert response =~ "Test Page Title"
      assert response =~ ~p"/pages/#{page}"
    end
  end

  describe "GET /pages/:slug" do
    test "renders a page for anonymous users", %{conn: conn} do
      page =
        static_page_fixture(user_fixture(), %{
          title: "Test About Page",
          body: "All *about* this test site."
        })

      conn = get(conn, ~p"/pages/#{page}")
      response = html_response(conn, 200)

      assert response =~ "Test About Page - Derpibooru"
      # Markdown body is rendered to HTML
      assert response =~ "All <em>about</em> this test site."
    end

    test "renders the edit link only for static-page managers", %{conn: conn} do
      page = static_page_fixture(user_fixture(), %{title: "Managed Page"})

      plain_response =
        html_response(get(log_in_user(conn, moderator_user_fixture()), ~p"/pages/#{page}"), 200)

      refute plain_response =~ ~p"/pages/#{page}/edit"

      role_response =
        html_response(get(log_in_role_moderator(conn, "StaticPage"), ~p"/pages/#{page}"), 200)

      assert role_response =~ "Edit"
      assert role_response =~ ~p"/pages/#{page}/edit"

      admin_response =
        html_response(get(log_in_user(conn, admin_user_fixture()), ~p"/pages/#{page}"), 200)

      assert admin_response =~ ~p"/pages/#{page}/edit"
    end

    test "redirects to / for an unknown slug", %{conn: conn} do
      conn = get(conn, ~p"/pages/nonexistent-page")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "GET /pages/new" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/pages/new")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "redirects to / for a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/pages/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end

    test "redirects to / for a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/pages/new")

      assert redirected_to(conn) == "/"
    end

    test "renders the form for a StaticPage-role moderator", %{conn: conn} do
      conn = log_in_role_moderator(conn, "StaticPage")

      conn = get(conn, ~p"/pages/new")
      response = html_response(conn, 200)

      assert response =~ "New Page - Derpibooru"
      assert response =~ "New static page"
    end

    test "renders the form for an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/pages/new")
      response = html_response(conn, 200)

      assert response =~ "New Page - Derpibooru"
      assert response =~ "New static page"
    end

    test "renders the form for an admin without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(without_fingerprint(conn), ~p"/pages/new")

      assert html_response(conn, 200) =~ "New Page - Derpibooru"
    end
  end

  describe "POST /pages (create)" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = post(conn, ~p"/pages", %{"static_page" => valid_page_params()})

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      params = valid_page_params(%{"slug" => "nope-page"})
      conn = post(conn, ~p"/pages", %{"static_page" => params})

      assert redirected_to(conn) == "/"
      refute Repo.get_by(StaticPage, slug: "nope-page")
    end

    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      params = valid_page_params(%{"slug" => "nope-mod-page"})
      conn = post(conn, ~p"/pages", %{"static_page" => params})

      assert redirected_to(conn) == "/"
      refute Repo.get_by(StaticPage, slug: "nope-mod-page")
    end

    test "creates a page (with a version) as an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      params = valid_page_params(%{"slug" => "admin-created-page"})
      conn = post(conn, ~p"/pages", %{"static_page" => params})

      assert redirected_to(conn) == ~p"/pages/admin-created-page"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "successfully created"

      page = Repo.get_by(StaticPage, slug: "admin-created-page")
      assert page
      # The create path records an initial version row attributed to the user.
      assert Repo.get_by(Version, static_page_id: page.id)
    end

    test "creates a page as a StaticPage-role moderator", %{conn: conn} do
      conn = log_in_role_moderator(conn, "StaticPage")

      params = valid_page_params(%{"slug" => "mod-created-page"})
      conn = post(conn, ~p"/pages", %{"static_page" => params})

      assert redirected_to(conn) == ~p"/pages/mod-created-page"
      assert Repo.get_by(StaticPage, slug: "mod-created-page")
    end

    test "re-renders the form on a validation failure", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      params = valid_page_params(%{"slug" => "invalid-page", "body" => ""})
      conn = post(conn, ~p"/pages", %{"static_page" => params})

      assert html_response(conn, 200) =~ "New static page"
      refute Repo.get_by(StaticPage, slug: "invalid-page")
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        post(without_fingerprint(conn), ~p"/pages", %{
          "static_page" => valid_page_params(%{"slug" => "fingerprintless-page"})
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get_by(StaticPage, slug: "fingerprintless-page")
    end
  end

  describe "GET /pages/:slug/edit" do
    test "rejects a regular user", %{conn: conn} do
      page = static_page_fixture(user_fixture())
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/pages/#{page}/edit")

      assert redirected_to(conn) == "/"
    end

    test "renders the edit form for an admin", %{conn: conn} do
      %{conn: conn, user: admin} = register_and_log_in_admin(%{conn: conn})
      page = static_page_fixture(admin, %{title: "Edit Me Page"})

      conn = get(conn, ~p"/pages/#{page}/edit")
      response = html_response(conn, 200)

      assert response =~ "Editing Page - Derpibooru"
      assert response =~ "Editing static page"
    end

    test "renders the edit form for a StaticPage-role moderator", %{conn: conn} do
      page = static_page_fixture(user_fixture())
      conn = log_in_role_moderator(conn, "StaticPage")

      conn = get(conn, ~p"/pages/#{page}/edit")

      assert html_response(conn, 200) =~ "Editing static page"
    end

    test "redirects with a not-found flash on an unknown slug for an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/pages/no-such-slug/edit")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking"
    end

    test "renders the edit form for an admin without a fingerprint", %{conn: conn} do
      %{conn: conn, user: admin} = register_and_log_in_admin(%{conn: conn})
      page = static_page_fixture(admin)
      conn = get(without_fingerprint(conn), ~p"/pages/#{page}/edit")

      assert html_response(conn, 200) =~ "Editing Page - Derpibooru"
    end
  end

  describe "PATCH /pages/:slug (update)" do
    test "rejects a regular user", %{conn: conn} do
      page = static_page_fixture(user_fixture(), %{title: "Original Title"})
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = patch(conn, ~p"/pages/#{page}", %{"static_page" => %{"title" => "Hacked"}})

      assert redirected_to(conn) == "/"
      assert Repo.get(StaticPage, page.id).title == "Original Title"
    end

    test "updates the page (with a version) as an admin", %{conn: conn} do
      %{conn: conn, user: admin} = register_and_log_in_admin(%{conn: conn})
      page = static_page_fixture(admin, %{title: "Original Title"})

      conn =
        patch(conn, ~p"/pages/#{page}", %{
          "static_page" => %{"title" => "Renamed Title", "slug" => page.slug, "body" => page.body}
        })

      assert redirected_to(conn) == ~p"/pages/#{page}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "successfully updated"
      assert Repo.get(StaticPage, page.id).title == "Renamed Title"
      # The update path records a new version row for every edit.
      assert Repo.aggregate(
               from(v in Version, where: v.static_page_id == ^page.id),
               :count
             ) == 2
    end

    test "re-renders the edit form on a validation failure", %{conn: conn} do
      %{conn: conn, user: admin} = register_and_log_in_admin(%{conn: conn})
      page = static_page_fixture(admin, %{title: "Original Title"})

      conn =
        patch(conn, ~p"/pages/#{page}", %{
          "static_page" => %{"title" => "", "slug" => page.slug, "body" => page.body}
        })

      assert html_response(conn, 200) =~ "Editing static page"
      assert Repo.get(StaticPage, page.id).title == "Original Title"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn, user: admin} = register_and_log_in_admin(%{conn: conn})
      page = static_page_fixture(admin)

      conn =
        patch(without_fingerprint(conn), ~p"/pages/#{page}", %{
          "static_page" => %{"title" => "Renamed Title", "slug" => page.slug, "body" => page.body}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(StaticPage, page.id).title == page.title
    end
  end

  describe "PUT /pages/:slug (update)" do
    test "updates the page as an admin", %{conn: conn} do
      %{conn: conn, user: admin} = register_and_log_in_admin(%{conn: conn})
      page = static_page_fixture(admin, %{title: "Original Title"})

      conn =
        put(conn, ~p"/pages/#{page}", %{
          "static_page" => %{"title" => "Put Renamed", "slug" => page.slug, "body" => page.body}
        })

      assert redirected_to(conn) == ~p"/pages/#{page}"
      assert Repo.get(StaticPage, page.id).title == "Put Renamed"
    end
  end
end
