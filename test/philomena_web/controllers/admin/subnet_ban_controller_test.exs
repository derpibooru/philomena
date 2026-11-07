defmodule PhilomenaWeb.Admin.SubnetBanControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.BansFixtures

  alias Philomena.Bans.Subnet, as: SubnetBan
  alias Philomena.Repo

  describe "GET /admin/subnet_bans (index) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/subnet_bans")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/subnet_bans")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/subnet_bans")
      assert html_response(conn, 200) =~ "Subnet Bans"
    end

    test "allows an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/subnet_bans")
      assert html_response(conn, 200) =~ "Subnet Bans"
    end
  end

  describe "GET /admin/subnet_bans (index) content" do
    setup [:register_and_log_in_admin]

    test "renders the empty index", %{conn: conn} do
      conn = get(conn, ~p"/admin/subnet_bans")
      response = html_response(conn, 200)
      assert response =~ "Admin - Subnet Bans - Derpibooru"
    end

    test "lists an existing ban", %{conn: conn} do
      ban = subnet_ban_fixture()
      conn = get(conn, ~p"/admin/subnet_bans")
      response = html_response(conn, 200)
      assert response =~ ban.generated_ban_id
      assert response =~ "Test subnet reason"
    end

    test "filters by the bq search branch", %{conn: conn} do
      ban = subnet_ban_fixture()
      conn = get(conn, ~p"/admin/subnet_bans?#{[bq: ban.generated_ban_id]}")
      response = html_response(conn, 200)
      assert response =~ ban.generated_ban_id
    end

    test "filters by the ip branch", %{conn: conn} do
      ban = subnet_ban_fixture()
      conn = get(conn, ~p"/admin/subnet_bans?#{[ip: "203.0.113.5"]}")
      response = html_response(conn, 200)
      assert response =~ ban.generated_ban_id
    end

    test "renders an inline error on an invalid ip in the ip branch", %{conn: conn} do
      conn = get(conn, ~p"/admin/subnet_bans?#{[ip: "not-an-ip"]}")

      response = html_response(conn, 200)
      assert response =~ "Ip is invalid"
    end
  end

  describe "GET /admin/subnet_bans/new" do
    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/subnet_bans/new")
      assert redirected_to(conn) == "/"
    end

    test "renders a blank form for a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/subnet_bans/new")
      assert html_response(conn, 200) =~ "New Subnet Ban"
    end

    test "prefills the form when a specification is supplied", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/subnet_bans/new?#{[specification: "203.0.113.0/24"]}")

      response = html_response(conn, 200)
      assert response =~ "New Subnet Ban"
      assert response =~ "203.0.113.0/24"
    end

    test "renders the form for a moderator without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/admin/subnet_bans/new")

      assert html_response(conn, 200) =~ "New Subnet Ban"
    end
  end

  describe "POST /admin/subnet_bans (create)" do
    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/admin/subnet_bans", %{
          "subnet" => %{
            "specification" => "198.51.100.0/24",
            "reason" => "nope",
            "valid_until" => "5 years from now"
          }
        })

      assert redirected_to(conn) == "/"
      refute Repo.exists?(SubnetBan)
    end

    test "creates a ban as a moderator and logs it", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/admin/subnet_bans", %{
          "subnet" => %{
            "specification" => "198.51.100.0/24",
            "reason" => "Abusive subnet",
            "valid_until" => "5 years from now"
          }
        })

      assert redirected_to(conn) == ~p"/admin/subnet_bans"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Subnet was successfully banned."
      assert Repo.get_by(SubnetBan, reason: "Abusive subnet")
    end

    test "creates a ban as an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        post(conn, ~p"/admin/subnet_bans", %{
          "subnet" => %{
            "specification" => "198.51.100.0/24",
            "reason" => "Admin issued subnet",
            "valid_until" => "5 years from now"
          }
        })

      assert redirected_to(conn) == ~p"/admin/subnet_bans"
      assert Repo.get_by(SubnetBan, reason: "Admin issued subnet")
    end

    test "re-renders the form on a validation failure", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/admin/subnet_bans", %{
          "subnet" => %{
            "specification" => "198.51.100.0/24",
            "valid_until" => "5 years from now"
          }
        })

      assert html_response(conn, 200) =~ "New Subnet Ban"
      refute Repo.exists?(SubnetBan)
    end

    test "renders an inline error on an invalid specification", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        post(conn, ~p"/admin/subnet_bans", %{
          "subnet" => %{
            "specification" => "not-an-ip",
            "valid_until" => "5 years from now"
          }
        })

      response = html_response(conn, 200)
      assert response =~ "New Subnet Ban"
      assert response =~ "Specification is invalid"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(without_fingerprint(conn), ~p"/admin/subnet_bans", %{
          "subnet" => %{
            "specification" => "198.51.100.0/24",
            "reason" => "Fingerprintless ban",
            "valid_until" => "5 years from now"
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get_by(SubnetBan, reason: "Fingerprintless ban")
    end
  end

  describe "GET /admin/subnet_bans/:id/edit" do
    test "rejects a regular user", %{conn: conn} do
      ban = subnet_ban_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/subnet_bans/#{ban}/edit")
      assert redirected_to(conn) == "/"
    end

    test "renders the edit form for a moderator", %{conn: conn} do
      ban = subnet_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/subnet_bans/#{ban}/edit")
      assert html_response(conn, 200) =~ "Editing ban"
    end

    test "redirects to / with a not-found flash for an unknown id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/subnet_bans/#{2_000_000_000}/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects to / with a not-found flash for a non-integer id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/admin/subnet_bans/not-a-number/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the edit form for a moderator without a fingerprint", %{conn: conn} do
      ban = subnet_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/admin/subnet_bans/#{ban}/edit")

      assert html_response(conn, 200) =~ "Editing ban"
    end
  end

  describe "PATCH /admin/subnet_bans/:id (update)" do
    test "rejects a regular user", %{conn: conn} do
      ban = subnet_ban_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = patch(conn, ~p"/admin/subnet_bans/#{ban}", %{"subnet" => %{"reason" => "changed"}})
      assert redirected_to(conn) == "/"
    end

    test "updates the ban as a moderator", %{conn: conn} do
      ban = subnet_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/subnet_bans/#{ban}", %{
          "subnet" => %{"reason" => "Updated subnet reason"}
        })

      assert redirected_to(conn) == ~p"/admin/subnet_bans"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Subnet ban successfully updated."
      assert Repo.get(SubnetBan, ban.id).reason == "Updated subnet reason"
    end

    test "re-renders the edit form on a validation failure", %{conn: conn} do
      ban = subnet_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/subnet_bans/#{ban}", %{
          "subnet" => %{"reason" => ""}
        })

      assert html_response(conn, 200) =~ "Editing ban"
      assert Repo.get(SubnetBan, ban.id).reason == "Test subnet reason"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      ban = subnet_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(without_fingerprint(conn), ~p"/admin/subnet_bans/#{ban}", %{
          "subnet" => %{"reason" => "Updated reason"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(SubnetBan, ban.id).reason == ban.reason
    end
  end

  describe "PUT /admin/subnet_bans/:id (update)" do
    test "updates the ban as an admin", %{conn: conn} do
      ban = subnet_ban_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        put(conn, ~p"/admin/subnet_bans/#{ban}", %{
          "subnet" => %{"reason" => "Put updated subnet"}
        })

      assert redirected_to(conn) == ~p"/admin/subnet_bans"
      assert Repo.get(SubnetBan, ban.id).reason == "Put updated subnet"
    end
  end

  describe "DELETE /admin/subnet_bans/:id" do
    test "rejects a regular user", %{conn: conn} do
      ban = subnet_ban_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = delete(conn, ~p"/admin/subnet_bans/#{ban}")
      assert redirected_to(conn) == "/"
      assert Repo.get(SubnetBan, ban.id)
    end

    # NOTE: delete requires role == "admin"; a moderator is rejected.
    test "rejects a moderator", %{conn: conn} do
      ban = subnet_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = delete(conn, ~p"/admin/subnet_bans/#{ban}")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(SubnetBan, ban.id)
    end

    test "deletes the ban as an admin", %{conn: conn} do
      ban = subnet_ban_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = delete(conn, ~p"/admin/subnet_bans/#{ban}")
      assert redirected_to(conn) == ~p"/admin/subnet_bans"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Subnet ban successfully deleted."
      refute Repo.get(SubnetBan, ban.id)
    end
  end
end
