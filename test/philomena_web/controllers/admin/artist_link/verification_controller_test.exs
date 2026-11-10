defmodule PhilomenaWeb.Admin.ArtistLink.VerificationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ArtistLinksFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.Repo

  defp artist_link!(_context) do
    user = confirmed_user_fixture()
    tag = tag_fixture(name: "artist:verify-#{System.unique_integer([:positive])}")
    %{artist_link: artist_link_fixture(user, tag)}
  end

  describe "POST /admin/artist_links/:artist_link_id/verification authorization" do
    setup :artist_link!

    test "redirects anonymous users to login", %{conn: conn, artist_link: link} do
      conn = post(conn, ~p"/admin/artist_links/#{link}/verification")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn, artist_link: link} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = post(conn, ~p"/admin/artist_links/#{link}/verification")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "POST /admin/artist_links/:artist_link_id/verification (create)" do
    setup [:register_and_log_in_moderator, :artist_link!]

    test "verifies the link and redirects to the index", %{conn: conn, artist_link: link} do
      conn = post(conn, ~p"/admin/artist_links/#{link}/verification")
      assert redirected_to(conn) == ~p"/admin/artist_links"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "verified"

      assert Repo.get(ArtistLink, link.id).aasm_state == "verified"
    end
  end

  describe "POST /admin/artist_links/:artist_link_id/verification (create) failure paths" do
    setup [:register_and_log_in_moderator]

    test "redirects for an unknown link id", %{conn: conn} do
      conn = post(conn, ~p"/admin/artist_links/#{0}/verification")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects with the not-found flash for a non-integer link id", %{conn: conn} do
      conn = post(conn, ~p"/admin/artist_links/not-an-integer/verification")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
