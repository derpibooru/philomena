defmodule PhilomenaWeb.Admin.FingerprintBanControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.BansFixtures

  alias Philomena.Bans.Fingerprint, as: FingerprintBan
  alias Philomena.Repo

  describe "GET /admin/fingerprint_bans (index) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/fingerprint_bans")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/fingerprint_bans")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/fingerprint_bans")
      assert html_response(conn, 200) =~ "Fingerprint Bans"
    end

    test "allows an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/fingerprint_bans")
      assert html_response(conn, 200) =~ "Fingerprint Bans"
    end
  end

  describe "GET /admin/fingerprint_bans (index) content" do
    setup [:register_and_log_in_admin]

    test "renders the empty index", %{conn: conn} do
      conn = get(conn, ~p"/admin/fingerprint_bans")
      response = html_response(conn, 200)
      assert response =~ "Admin - Fingerprint Bans - Derpibooru"
    end

    test "lists an existing ban", %{conn: conn} do
      ban = fingerprint_ban_fixture()
      conn = get(conn, ~p"/admin/fingerprint_bans")
      response = html_response(conn, 200)
      assert response =~ ban.generated_ban_id
      assert response =~ "Test fingerprint reason"
    end

    test "filters by the bq search branch", %{conn: conn} do
      ban = fingerprint_ban_fixture()
      conn = get(conn, ~p"/admin/fingerprint_bans?#{[bq: ban.generated_ban_id]}")
      response = html_response(conn, 200)
      assert response =~ ban.generated_ban_id
    end

    test "filters by the fingerprint branch", %{conn: conn} do
      ban = fingerprint_ban_fixture()
      conn = get(conn, ~p"/admin/fingerprint_bans?#{[fingerprint: ban.fingerprint]}")
      response = html_response(conn, 200)
      assert response =~ ban.generated_ban_id
    end
  end

  describe "GET /admin/fingerprint_bans/new" do
    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/fingerprint_bans/new")
      assert redirected_to(conn) == "/"
    end

    test "renders a blank form for a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/fingerprint_bans/new")
      assert html_response(conn, 200) =~ "New Fingerprint Ban"
    end

    test "prefills the form when a fingerprint is supplied", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/fingerprint_bans/new?#{[fingerprint: "abcdef0123456789"]}")
      assert html_response(conn, 200) =~ "New Fingerprint Ban"
    end

    test "renders the form for a moderator without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/admin/fingerprint_bans/new")

      assert html_response(conn, 200) =~ "New Fingerprint Ban"
    end
  end

  describe "POST /admin/fingerprint_bans (create)" do
    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/admin/fingerprint_bans", %{
          "fingerprint" => %{
            "fingerprint" => "abcdef0123456789",
            "reason" => "nope",
            "valid_until" => "5 years from now"
          }
        })

      assert redirected_to(conn) == "/"
      refute Repo.exists?(FingerprintBan)
    end

    test "creates a ban as a moderator and logs it", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/admin/fingerprint_bans", %{
          "fingerprint" => %{
            "fingerprint" => "abcdef0123456789",
            "reason" => "Ban evader",
            "valid_until" => "5 years from now"
          }
        })

      assert redirected_to(conn) == ~p"/admin/fingerprint_bans"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Fingerprint was successfully banned."

      assert Repo.get_by(FingerprintBan, reason: "Ban evader")
    end

    test "creates a ban as an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        post(conn, ~p"/admin/fingerprint_bans", %{
          "fingerprint" => %{
            "fingerprint" => "abcdef0123456789",
            "reason" => "Admin issued fingerprint",
            "valid_until" => "5 years from now"
          }
        })

      assert redirected_to(conn) == ~p"/admin/fingerprint_bans"
      assert Repo.get_by(FingerprintBan, reason: "Admin issued fingerprint")
    end

    test "re-renders the form on a validation failure", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/admin/fingerprint_bans", %{
          "fingerprint" => %{
            "fingerprint" => "abcdef0123456789",
            "valid_until" => "5 years from now"
          }
        })

      assert html_response(conn, 200) =~ "New Fingerprint Ban"
      refute Repo.exists?(FingerprintBan)
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(without_fingerprint(conn), ~p"/admin/fingerprint_bans", %{
          "fingerprint" => %{
            "fingerprint" => "abcdef0123456789",
            "reason" => "Fingerprintless ban",
            "valid_until" => "5 years from now"
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get_by(FingerprintBan, reason: "Fingerprintless ban")
    end
  end

  describe "GET /admin/fingerprint_bans/:id/edit" do
    test "rejects a regular user", %{conn: conn} do
      ban = fingerprint_ban_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/fingerprint_bans/#{ban}/edit")
      assert redirected_to(conn) == "/"
    end

    test "renders the edit form for a moderator", %{conn: conn} do
      ban = fingerprint_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/fingerprint_bans/#{ban}/edit")
      assert html_response(conn, 200) =~ "Editing ban"
    end

    test "redirects to / with a not-found flash for an unknown id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/fingerprint_bans/#{2_000_000_000}/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects with a not-found flash for a non-integer id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/admin/fingerprint_bans/not-a-number/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the edit form for a moderator without a fingerprint", %{conn: conn} do
      ban = fingerprint_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/admin/fingerprint_bans/#{ban}/edit")

      assert html_response(conn, 200) =~ "Editing ban"
    end
  end

  describe "PATCH /admin/fingerprint_bans/:id (update)" do
    test "rejects a regular user", %{conn: conn} do
      ban = fingerprint_ban_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/fingerprint_bans/#{ban}", %{
          "fingerprint" => %{"reason" => "changed"}
        })

      assert redirected_to(conn) == "/"
    end

    test "updates the ban as a moderator", %{conn: conn} do
      ban = fingerprint_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/fingerprint_bans/#{ban}", %{
          "fingerprint" => %{"reason" => "Updated fingerprint reason"}
        })

      assert redirected_to(conn) == ~p"/admin/fingerprint_bans"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Fingerprint ban successfully updated."

      assert Repo.get(FingerprintBan, ban.id).reason == "Updated fingerprint reason"
    end

    test "re-renders the edit form on a validation failure", %{conn: conn} do
      ban = fingerprint_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/fingerprint_bans/#{ban}", %{
          "fingerprint" => %{"reason" => ""}
        })

      assert html_response(conn, 200) =~ "Editing ban"
      assert Repo.get(FingerprintBan, ban.id).reason == "Test fingerprint reason"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      ban = fingerprint_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(without_fingerprint(conn), ~p"/admin/fingerprint_bans/#{ban}", %{
          "fingerprint" => %{"reason" => "Updated reason"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(FingerprintBan, ban.id).reason == ban.reason
    end
  end

  describe "PUT /admin/fingerprint_bans/:id (update)" do
    test "updates the ban as an admin", %{conn: conn} do
      ban = fingerprint_ban_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        put(conn, ~p"/admin/fingerprint_bans/#{ban}", %{
          "fingerprint" => %{"reason" => "Put updated fingerprint"}
        })

      assert redirected_to(conn) == ~p"/admin/fingerprint_bans"
      assert Repo.get(FingerprintBan, ban.id).reason == "Put updated fingerprint"
    end
  end

  describe "DELETE /admin/fingerprint_bans/:id" do
    test "rejects a regular user", %{conn: conn} do
      ban = fingerprint_ban_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = delete(conn, ~p"/admin/fingerprint_bans/#{ban}")
      assert redirected_to(conn) == "/"
      assert Repo.get(FingerprintBan, ban.id)
    end

    # NOTE: delete requires role == "admin"; a moderator is rejected.
    test "rejects a moderator", %{conn: conn} do
      ban = fingerprint_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = delete(conn, ~p"/admin/fingerprint_bans/#{ban}")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(FingerprintBan, ban.id)
    end

    test "deletes the ban as an admin", %{conn: conn} do
      ban = fingerprint_ban_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = delete(conn, ~p"/admin/fingerprint_bans/#{ban}")
      assert redirected_to(conn) == ~p"/admin/fingerprint_bans"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Fingerprint ban successfully deleted."

      refute Repo.get(FingerprintBan, ban.id)
    end
  end
end
