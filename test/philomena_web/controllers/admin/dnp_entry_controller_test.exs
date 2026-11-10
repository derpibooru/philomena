defmodule PhilomenaWeb.Admin.DnpEntryControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.DnpEntriesFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  describe "GET /admin/dnp_entries authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/dnp_entries")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/dnp_entries")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/dnp_entries")
      assert html_response(conn, 200) =~ "Do-Not-Post Requests"
    end

    test "allows an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/dnp_entries")
      assert html_response(conn, 200) =~ "Do-Not-Post Requests"
    end
  end

  describe "GET /admin/dnp_entries (index) content" do
    setup [:register_and_log_in_admin]

    test "an empty eq parameter uses the default DNP entry query", %{conn: conn} do
      user = confirmed_user_fixture()
      tag = tag_fixture(name: "artist:dnp-empty-query")
      entry = dnp_entry_fixture(user, tag)

      conn = get(conn, ~p"/admin/dnp_entries?eq=")

      assert html_response(conn, 200) =~ ~p"/dnp/#{entry}"
    end

    test "renders the empty index", %{conn: conn} do
      conn = get(conn, ~p"/admin/dnp_entries")
      response = html_response(conn, 200)
      assert response =~ "Admin - DNP Entries - Derpibooru"
      assert response =~ "Do-Not-Post Requests"
    end

    test "lists a requested entry by default", %{conn: conn} do
      user = confirmed_user_fixture()
      tag = tag_fixture(name: "artist:dnp-requested")
      entry = dnp_entry_fixture(user, tag)

      conn = get(conn, ~p"/admin/dnp_entries")
      response = html_response(conn, 200)
      assert response =~ ~p"/dnp/#{entry}"
      assert response =~ "dnp-requested"
    end

    # NOTE: the default index only lists the active states (requested/claimed/
    # rescinded/acknowledged) - a "listed" entry is hidden unless states[] asks.
    test "hides a listed entry by default but shows it with states[]", %{conn: conn} do
      user = confirmed_user_fixture()
      tag = tag_fixture(name: "artist:dnp-listed")
      entry = dnp_entry_fixture(user, tag, %{state: "listed"})

      conn = get(conn, ~p"/admin/dnp_entries")
      refute html_response(conn, 200) =~ ~p"/dnp/#{entry}"

      conn = get(conn, ~p"/admin/dnp_entries?#{[eq: [states: ["listed"]]]}")
      assert html_response(conn, 200) =~ ~p"/dnp/#{entry}"
    end

    test "filters by user, tag, reason, or conditions with eq", %{conn: conn} do
      user = confirmed_user_fixture()
      tag = tag_fixture(name: "artist:dnp-eq-match")
      entry = dnp_entry_fixture(user, tag)

      other_user = confirmed_user_fixture()
      other_tag = tag_fixture(name: "artist:dnp-eq-other")
      other_entry = dnp_entry_fixture(other_user, other_tag)

      conn = get(conn, ~p"/admin/dnp_entries?#{[eq: [text: "dnp-eq-match"]]}")
      response = html_response(conn, 200)
      assert response =~ ~p"/dnp/#{entry}"
      refute response =~ ~p"/dnp/#{other_entry}"
    end
  end
end
