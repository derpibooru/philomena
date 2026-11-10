defmodule PhilomenaWeb.Admin.DonationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.DonationsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Donations.Donation
  alias Philomena.Repo

  describe "GET /admin/donations authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/donations")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/donations")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: donations have no moderator ability rule - only admins (the catch-all
    # `role: "admin"` grant) can reach the admin donation controllers.
    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/donations")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/donations")
      assert html_response(conn, 200) =~ "Donations"
    end
  end

  describe "GET /admin/donations (index) content" do
    setup [:register_and_log_in_admin]

    test "renders the empty index", %{conn: conn} do
      conn = get(conn, ~p"/admin/donations")
      response = html_response(conn, 200)
      assert response =~ "Admin - Donations - Derpibooru"
      assert response =~ "Donations"
    end

    test "lists an existing donation", %{conn: conn} do
      donation = donation_fixture()
      conn = get(conn, ~p"/admin/donations")
      assert html_response(conn, 200) =~ donation.email
    end
  end

  describe "POST /admin/donations authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = post(conn, ~p"/admin/donations", donation: %{"amount" => "5.00"})
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = post(conn, ~p"/admin/donations", donation: %{"amount" => "5.00"})
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "gives a banned admin the ban response", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_admin(%{conn: conn})
      before = Repo.aggregate(Donation, :count)

      conn = post(conn, ~p"/admin/donations", donation: %{"amount" => "5.00"})

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You are currently banned."
      assert Repo.aggregate(Donation, :count) == before
    end
  end

  describe "POST /admin/donations (create)" do
    setup [:register_and_log_in_admin]

    test "creates a donation and redirects to the index", %{conn: conn} do
      user = confirmed_user_fixture()

      conn =
        post(conn, ~p"/admin/donations",
          donation: %{"email" => "created@example.com", "amount" => "10.00", "user_id" => user.id}
        )

      assert redirected_to(conn) == ~p"/admin/donations"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "successfully created"

      assert Repo.get_by(Donation, email: "created@example.com")
    end

    # NOTE: every donation field is optional in the changeset, so even an empty
    # donation map inserts a row successfully.
    test "creates a donation from an empty params map", %{conn: conn} do
      before = Repo.aggregate(Donation, :count)

      conn = post(conn, ~p"/admin/donations", donation: %{})

      assert redirected_to(conn) == ~p"/admin/donations"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "successfully created"
      assert Repo.aggregate(Donation, :count) == before + 1
    end

    # NOTE: a user_id with no matching user hits the FK constraint, taking the
    # error branch (a flash, not a crash).
    test "shows the error flash on a foreign key violation", %{conn: conn} do
      conn = post(conn, ~p"/admin/donations", donation: %{"user_id" => 2_000_000_000})

      assert redirected_to(conn) == ~p"/admin/donations"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Error creating donation"
    end

    # NOTE: a missing "donation" param does not match create/2 and raises
    # Phoenix.ActionClauseError (a 500).
    test "raises when the donation param is missing", %{conn: conn} do
      assert_raise Phoenix.ActionClauseError, fn ->
        post(conn, ~p"/admin/donations")
      end
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      conn =
        post(without_fingerprint(conn), ~p"/admin/donations",
          donation: %{"email" => "fingerprintless@example.com"}
        )

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get_by(Donation, email: "fingerprintless@example.com")
    end
  end
end
