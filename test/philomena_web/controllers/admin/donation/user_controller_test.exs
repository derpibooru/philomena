defmodule PhilomenaWeb.Admin.Donation.UserControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.DonationsFixtures
  import Philomena.UsersFixtures

  describe "GET /admin/donations/user/:id authorization" do
    setup do
      %{target: confirmed_user_fixture()}
    end

    test "redirects anonymous users to login", %{conn: conn, target: target} do
      conn = get(conn, ~p"/admin/donations/user/#{target.slug}")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn, target: target} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/donations/user/#{target.slug}")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: donations are admin-only; a plain moderator is rejected.
    test "rejects a plain moderator", %{conn: conn, target: target} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/donations/user/#{target.slug}")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "GET /admin/donations/user/:id (show)" do
    setup [:register_and_log_in_admin]

    test "renders the donation form for a user with no donations", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = get(conn, ~p"/admin/donations/user/#{target.slug}")
      response = html_response(conn, 200)
      assert response =~ "Donations for User"
      assert response =~ target.name
      assert response =~ "Add Donation"
    end

    test "lists the user's donations", %{conn: conn} do
      target = confirmed_user_fixture()
      donation = donation_fixture(target)

      conn = get(conn, ~p"/admin/donations/user/#{target.slug}")
      response = html_response(conn, 200)
      assert response =~ donation.email
    end

    # NOTE: the context authorizes the loaded record on :show; an unknown slug
    # loads nil, the actor is authorized on it, so it returns not_found and
    # redirects to / with the not-found flash rather than crashing.
    test "redirects for an unknown user slug", %{conn: conn} do
      conn = get(conn, ~p"/admin/donations/user/no-such-user")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the donation form without a fingerprint", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = get(without_fingerprint(conn), ~p"/admin/donations/user/#{target.slug}")

      assert html_response(conn, 200) =~ "Add Donation"
    end
  end
end
