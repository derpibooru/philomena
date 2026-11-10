defmodule PhilomenaWeb.LayoutViewTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures
  alias PhilomenaWeb.LayoutView

  defp staff_links(conn, user) do
    conn = viewer_conn(conn, user)

    Phoenix.View.render_to_string(
      LayoutView,
      "_header_staff_links.html",
      Map.put(conn.assigns, :conn, conn)
    )
  end

  defp tool_visibility(conn, user) do
    conn = viewer_conn(conn, user)

    %{
      hidden_images: LayoutView.hides_images?(conn),
      site_notices: LayoutView.manages_site_notices?(conn),
      tags: LayoutView.manages_tags?(conn),
      users: LayoutView.manages_users?(conn),
      forums: LayoutView.manages_forums?(conn),
      adverts: LayoutView.manages_ads?(conn),
      badges: LayoutView.manages_badges?(conn),
      static_pages: LayoutView.manages_static_pages?(conn),
      mod_notes: LayoutView.manages_mod_notes?(conn),
      bans: LayoutView.manages_bans?(conn),
      moderation_log: LayoutView.can_see_moderation_log?(conn)
    }
  end

  describe "staff tool visibility" do
    test "anonymous and regular viewers see no staff tools", %{conn: conn} do
      expected = %{
        hidden_images: false,
        site_notices: false,
        tags: false,
        users: false,
        forums: false,
        adverts: false,
        badges: false,
        static_pages: false,
        mod_notes: false,
        bans: false,
        moderation_log: false
      }

      user = user_fixture()
      assert tool_visibility(conn, nil) == expected
      assert tool_visibility(conn, user) == expected
    end

    test "a plain moderator sees core moderation tools only", %{conn: conn} do
      moderator = moderator_user_fixture()
      visibility = tool_visibility(conn, moderator)

      assert visibility == %{
               hidden_images: true,
               site_notices: false,
               tags: true,
               users: true,
               forums: false,
               adverts: false,
               badges: false,
               static_pages: false,
               mod_notes: true,
               bans: true,
               moderation_log: true
             }
    end

    test "resource role-map grants expose privileged staff tools", %{conn: conn} do
      privileged_moderator =
        role_user_fixture("moderator", [
          {"admin", "SiteNotice"},
          {"admin", "Tag"},
          {"moderator", "User"},
          {"admin", "Advert"},
          {"admin", "Badge"},
          {"admin", "StaticPage"}
        ])

      assert tool_visibility(conn, privileged_moderator) == %{
               hidden_images: true,
               site_notices: true,
               tags: true,
               users: true,
               forums: false,
               adverts: true,
               badges: true,
               static_pages: true,
               mod_notes: true,
               bans: true,
               moderation_log: true
             }
    end

    test "admins see every staff tool", %{conn: conn} do
      admin = admin_user_fixture()

      assert tool_visibility(conn, admin) == %{
               hidden_images: true,
               site_notices: true,
               tags: true,
               users: true,
               forums: true,
               adverts: true,
               badges: true,
               static_pages: true,
               mod_notes: true,
               bans: true,
               moderation_log: true
             }
    end
  end

  describe "_header_staff_links.html" do
    test "renders only the tools granted to a plain moderator", %{conn: conn} do
      moderator = moderator_user_fixture()
      response = staff_links(conn, moderator)

      assert response =~ "Users"
      assert response =~ "Mod Notes"
      assert response =~ "Mod Logs"
      assert response =~ "User Bans"
      assert response =~ "IP Bans"
      assert response =~ "FP Bans"

      refute response =~ "Site Notices"
      refute response =~ "Forums"
      refute response =~ "Adverts"
      refute response =~ "Badges"
      refute response =~ "Pages"
    end

    test "renders all resource-management links for an admin", %{conn: conn} do
      admin = admin_user_fixture()
      response = staff_links(conn, admin)

      for label <- [
            "Site Notices",
            "Users",
            "Forums",
            "Adverts",
            "Badges",
            "Pages",
            "Mod Notes",
            "Mod Logs",
            "User Bans",
            "IP Bans",
            "FP Bans"
          ] do
        assert response =~ label
      end
    end
  end
end
