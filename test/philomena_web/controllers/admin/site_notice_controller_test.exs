defmodule PhilomenaWeb.Admin.SiteNoticeControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.SiteNoticesFixtures

  alias Philomena.SiteNotices.SiteNotice
  alias Philomena.Repo

  describe "GET /admin/site_notices (index) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/site_notices")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/site_notices")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: Unlike the ban controllers, a plain moderator CANNOT manage site
    # notices - the ability is gated on the SiteNotice-admin role_map entry.
    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/site_notices")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows a privileged moderator (SiteNotice role_map)", %{conn: conn} do
      conn = log_in_role_moderator(conn, "SiteNotice")
      conn = get(conn, ~p"/admin/site_notices")
      assert html_response(conn, 200) =~ "Site Notices"
    end

    test "allows an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/site_notices")
      assert html_response(conn, 200) =~ "Site Notices"
    end
  end

  describe "GET /admin/site_notices (index) content" do
    setup [:register_and_log_in_admin]

    test "renders the empty index", %{conn: conn} do
      conn = get(conn, ~p"/admin/site_notices")
      response = html_response(conn, 200)
      assert response =~ "Admin - Site Notices - Derpibooru"
      assert response =~ "Site Notices"
    end

    test "lists an existing notice", %{conn: conn} do
      notice = site_notice_fixture()
      conn = get(conn, ~p"/admin/site_notices")
      response = html_response(conn, 200)
      assert response =~ notice.title
    end
  end

  describe "GET /admin/site_notices/new" do
    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/site_notices/new")
      assert redirected_to(conn) == "/"
    end

    test "renders the form for an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/site_notices/new")
      assert html_response(conn, 200) =~ "New site notice"
    end

    test "renders the form for an admin without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(without_fingerprint(conn), ~p"/admin/site_notices/new")

      assert html_response(conn, 200) =~ "New site notice"
    end
  end

  describe "POST /admin/site_notices (create)" do
    test "gives a banned admin the ban response", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_admin(%{conn: conn})

      conn =
        post(conn, ~p"/admin/site_notices", %{
          "site_notice" => %{
            "title" => "nope",
            "text" => "nope",
            "start_date" => "now",
            "finish_date" => "5 years from now"
          }
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You are currently banned."
      refute Repo.exists?(SiteNotice)
    end

    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/admin/site_notices", %{
          "site_notice" => %{
            "title" => "nope",
            "text" => "nope",
            "start_date" => "now",
            "finish_date" => "5 years from now"
          }
        })

      assert redirected_to(conn) == "/"
      refute Repo.exists?(SiteNotice)
    end

    test "creates a notice as an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        post(conn, ~p"/admin/site_notices", %{
          "site_notice" => %{
            "title" => "Big announcement",
            "text" => "Read all about it.",
            "start_date" => "now",
            "finish_date" => "5 years from now"
          }
        })

      assert redirected_to(conn) == ~p"/admin/site_notices"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully created site notice."
      assert Repo.get_by(SiteNotice, title: "Big announcement")
    end

    test "re-renders the form on a validation failure", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        post(conn, ~p"/admin/site_notices", %{
          "site_notice" => %{
            "text" => "Missing title",
            "start_date" => "now",
            "finish_date" => "5 years from now"
          }
        })

      assert html_response(conn, 200) =~ "New site notice"
      refute Repo.exists?(SiteNotice)
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        post(without_fingerprint(conn), ~p"/admin/site_notices", %{
          "site_notice" => %{
            "title" => "Fingerprintless announcement",
            "text" => "Read all about it.",
            "start_date" => "now",
            "finish_date" => "5 years from now"
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get_by(SiteNotice, title: "Fingerprintless announcement")
    end
  end

  describe "GET /admin/site_notices/:id/edit" do
    test "rejects a plain moderator", %{conn: conn} do
      notice = site_notice_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/site_notices/#{notice}/edit")
      assert redirected_to(conn) == "/"
    end

    test "renders the edit form for an admin", %{conn: conn} do
      notice = site_notice_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/site_notices/#{notice}/edit")
      response = html_response(conn, 200)
      assert response =~ "Editing site notice"
    end

    test "redirects to / with a not-found flash for an unknown id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/site_notices/#{2_000_000_000}/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects with a not-found flash for a non-integer id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/admin/site_notices/not-a-number/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the edit form for an admin without a fingerprint", %{conn: conn} do
      notice = site_notice_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(without_fingerprint(conn), ~p"/admin/site_notices/#{notice}/edit")

      assert html_response(conn, 200) =~ "Editing site notice"
    end
  end

  describe "PATCH /admin/site_notices/:id (update)" do
    test "rejects a plain moderator", %{conn: conn} do
      notice = site_notice_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/site_notices/#{notice}", %{"site_notice" => %{"title" => "changed"}})

      assert redirected_to(conn) == "/"
    end

    test "updates the notice as an admin", %{conn: conn} do
      notice = site_notice_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/site_notices/#{notice}", %{
          "site_notice" => %{"title" => "Updated title"}
        })

      assert redirected_to(conn) == ~p"/admin/site_notices"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully updated site notice."
      assert Repo.get(SiteNotice, notice.id).title == "Updated title"
    end

    test "re-renders the edit form on a validation failure", %{conn: conn} do
      notice = site_notice_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/site_notices/#{notice}", %{
          "site_notice" => %{"title" => ""}
        })

      assert html_response(conn, 200) =~ "Editing site notice"
      assert Repo.get(SiteNotice, notice.id).title == "Scheduled maintenance"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      notice = site_notice_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        patch(without_fingerprint(conn), ~p"/admin/site_notices/#{notice}", %{
          "site_notice" => %{"title" => "Updated title"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(SiteNotice, notice.id).title == notice.title
    end
  end

  describe "PUT /admin/site_notices/:id (update)" do
    test "updates the notice as an admin", %{conn: conn} do
      notice = site_notice_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        put(conn, ~p"/admin/site_notices/#{notice}", %{
          "site_notice" => %{"title" => "Put updated title"}
        })

      assert redirected_to(conn) == ~p"/admin/site_notices"
      assert Repo.get(SiteNotice, notice.id).title == "Put updated title"
    end
  end

  describe "DELETE /admin/site_notices/:id" do
    test "rejects a plain moderator", %{conn: conn} do
      notice = site_notice_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = delete(conn, ~p"/admin/site_notices/#{notice}")
      assert redirected_to(conn) == "/"
      assert Repo.get(SiteNotice, notice.id)
    end

    # NOTE: SiteNotice has no admin-only delete gate (unlike the ban
    # controllers) - a privileged moderator can delete.
    test "deletes the notice as an admin", %{conn: conn} do
      notice = site_notice_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = delete(conn, ~p"/admin/site_notices/#{notice}")
      assert redirected_to(conn) == ~p"/admin/site_notices"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully deleted site notice."
      refute Repo.get(SiteNotice, notice.id)
    end
  end
end
