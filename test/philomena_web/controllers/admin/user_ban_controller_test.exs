defmodule PhilomenaWeb.Admin.UserBanControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.BansFixtures
  import Philomena.UsersFixtures

  alias Philomena.Bans.User, as: UserBan
  alias Philomena.Repo

  describe "GET /admin/user_bans (index) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/user_bans")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/user_bans")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/user_bans")
      assert html_response(conn, 200) =~ "User Bans"
    end

    test "allows an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/user_bans")
      assert html_response(conn, 200) =~ "User Bans"
    end
  end

  describe "GET /admin/user_bans (index) content" do
    setup [:register_and_log_in_admin]

    test "renders the empty index", %{conn: conn} do
      conn = get(conn, ~p"/admin/user_bans")
      response = html_response(conn, 200)
      assert response =~ "Admin - User Bans - Derpibooru"
      assert response =~ "User Bans"
    end

    test "lists an existing ban", %{conn: conn} do
      target = confirmed_user_fixture()
      ban = user_ban_fixture(target)
      conn = get(conn, ~p"/admin/user_bans")
      response = html_response(conn, 200)
      assert response =~ target.name
      assert response =~ ban.generated_ban_id
      assert response =~ "Test ban reason"
    end

    test "filters by the bq search branch", %{conn: conn} do
      ban = user_ban_fixture()
      conn = get(conn, ~p"/admin/user_bans?#{[bq: ban.generated_ban_id]}")
      response = html_response(conn, 200)
      assert response =~ ban.generated_ban_id
    end

    test "filters by the user_id branch", %{conn: conn} do
      target = confirmed_user_fixture()
      ban = user_ban_fixture(target)
      conn = get(conn, ~p"/admin/user_bans?#{[user_id: target.id]}")
      response = html_response(conn, 200)
      assert response =~ ban.generated_ban_id
    end
  end

  describe "GET /admin/user_bans/new" do
    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      target = confirmed_user_fixture()
      conn = get(conn, ~p"/admin/user_bans/new?#{[user_id: target.id]}")
      assert redirected_to(conn) == "/"
    end

    test "renders the form when a user_id is supplied", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      target = confirmed_user_fixture()
      conn = get(conn, ~p"/admin/user_bans/new?#{[user_id: target.id]}")
      response = html_response(conn, 200)
      assert response =~ "New User Ban - Derpibooru"
      assert response =~ "New User Ban for user"
      assert response =~ target.name
    end

    # NOTE: The parameterless new/2 clause flashes and redirects rather than
    # rendering a blank form (unlike subnet/fingerprint bans, which fall back
    # to an empty form).
    test "redirects with a flash when no user_id is given", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/user_bans/new")
      assert redirected_to(conn) == ~p"/admin/user_bans"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Must create ban on user."
    end

    test "renders the form for a moderator without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      target = confirmed_user_fixture()

      conn = get(without_fingerprint(conn), ~p"/admin/user_bans/new?#{[user_id: target.id]}")

      assert html_response(conn, 200) =~ "New User Ban - Derpibooru"
    end
  end

  describe "POST /admin/user_bans (create)" do
    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      target = confirmed_user_fixture()

      conn =
        post(conn, ~p"/admin/user_bans", %{
          "user" => %{
            "user_id" => target.id,
            "reason" => "nope",
            "valid_until" => "5 years from now"
          }
        })

      assert redirected_to(conn) == "/"
      refute Repo.exists?(UserBan)
    end

    test "creates a ban as a moderator and logs it", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      target = confirmed_user_fixture()

      conn =
        post(conn, ~p"/admin/user_bans", %{
          "user" => %{
            "user_id" => target.id,
            "reason" => "Persistent rule breaking",
            "valid_until" => "5 years from now"
          }
        })

      assert redirected_to(conn) == ~p"/admin/user_bans"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "User was successfully banned."
      assert Repo.get_by(UserBan, user_id: target.id, reason: "Persistent rule breaking")
    end

    test "creates a ban as an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      target = confirmed_user_fixture()

      conn =
        post(conn, ~p"/admin/user_bans", %{
          "user" => %{
            "user_id" => target.id,
            "reason" => "Admin issued",
            "valid_until" => "5 years from now"
          }
        })

      assert redirected_to(conn) == ~p"/admin/user_bans"
      assert Repo.get_by(UserBan, user_id: target.id, reason: "Admin issued")
    end

    # NOTE: the create error branch now re-renders "new.html" with the
    # @target_user assign resolved from the posted user_id, so a validation
    # failure (here, a missing reason) shows the form (200) rather than raising.
    test "re-renders the form on a validation failure", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      target = confirmed_user_fixture()

      conn =
        post(conn, ~p"/admin/user_bans", %{
          "user" => %{
            "user_id" => target.id,
            "valid_until" => "5 years from now"
          }
        })

      response = html_response(conn, 200)
      assert response =~ "New User Ban for user"
      assert response =~ target.name
      refute Repo.get_by(UserBan, user_id: target.id)
    end

    # NOTE: when the posted user_id names no user, the error branch takes the
    # no_target_user path and redirects with a flash instead of re-rendering.
    test "redirects with a flash when the user_id names no user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/admin/user_bans", %{
          "user" => %{"user_id" => 2_000_000_000, "valid_until" => "5 years from now"}
        })

      assert redirected_to(conn) == ~p"/admin/user_bans"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Must create ban on user."
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      target = confirmed_user_fixture()

      conn =
        post(without_fingerprint(conn), ~p"/admin/user_bans", %{
          "user" => %{
            "user_id" => target.id,
            "reason" => "Fingerprintless ban",
            "valid_until" => "5 years from now"
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get_by(UserBan, reason: "Fingerprintless ban")
    end
  end

  describe "GET /admin/user_bans/:id/edit" do
    test "rejects a regular user", %{conn: conn} do
      ban = user_ban_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/user_bans/#{ban}/edit")
      assert redirected_to(conn) == "/"
    end

    test "renders the edit form for a moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      ban = user_ban_fixture(target)
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/user_bans/#{ban}/edit")
      response = html_response(conn, 200)
      assert response =~ "Editing User Ban - Derpibooru"
      assert response =~ "Editing user ban for user"
      assert response =~ target.name
    end

    test "redirects to / with a not-found flash for an unknown id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/user_bans/#{2_000_000_000}/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    # NOTE: a non-integer id short-circuits to NotFoundPlug via the central
    # IntegerId guard rather than raising a cast error.
    test "redirects to / with a not-found flash for a non-integer id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/admin/user_bans/not-a-number/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the edit form for a moderator without a fingerprint", %{conn: conn} do
      ban = user_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/admin/user_bans/#{ban}/edit")

      assert html_response(conn, 200) =~ "Editing User Ban - Derpibooru"
    end
  end

  describe "PATCH /admin/user_bans/:id (update)" do
    test "rejects a regular user", %{conn: conn} do
      ban = user_ban_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = patch(conn, ~p"/admin/user_bans/#{ban}", %{"user" => %{"reason" => "changed"}})
      assert redirected_to(conn) == "/"
    end

    test "updates the ban as a moderator", %{conn: conn} do
      ban = user_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/user_bans/#{ban}", %{
          "user" => %{"reason" => "Updated reason"}
        })

      assert redirected_to(conn) == ~p"/admin/user_bans"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "User ban successfully updated."
      assert Repo.get(UserBan, ban.id).reason == "Updated reason"
    end

    test "re-renders the edit form on a validation failure", %{conn: conn} do
      ban = user_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/user_bans/#{ban}", %{
          "user" => %{"reason" => ""}
        })

      response = html_response(conn, 200)
      assert response =~ "Editing user ban for user"
      assert Repo.get(UserBan, ban.id).reason == "Test ban reason"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      ban = user_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(without_fingerprint(conn), ~p"/admin/user_bans/#{ban}", %{
          "user" => %{"reason" => "Updated reason"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(UserBan, ban.id).reason == ban.reason
    end
  end

  describe "PUT /admin/user_bans/:id (update)" do
    test "updates the ban as an admin", %{conn: conn} do
      ban = user_ban_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        put(conn, ~p"/admin/user_bans/#{ban}", %{
          "user" => %{"reason" => "Put updated reason"}
        })

      assert redirected_to(conn) == ~p"/admin/user_bans"
      assert Repo.get(UserBan, ban.id).reason == "Put updated reason"
    end
  end

  describe "DELETE /admin/user_bans/:id" do
    test "rejects a regular user", %{conn: conn} do
      ban = user_ban_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = delete(conn, ~p"/admin/user_bans/#{ban}")
      assert redirected_to(conn) == "/"
      assert Repo.get(UserBan, ban.id)
    end

    # NOTE: delete is gated by check_can_delete (role == "admin"), so a
    # moderator - who can create/edit/update bans - cannot delete them.
    test "rejects a moderator", %{conn: conn} do
      ban = user_ban_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = delete(conn, ~p"/admin/user_bans/#{ban}")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(UserBan, ban.id)
    end

    test "deletes the ban as an admin", %{conn: conn} do
      ban = user_ban_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = delete(conn, ~p"/admin/user_bans/#{ban}")
      assert redirected_to(conn) == ~p"/admin/user_bans"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "User ban successfully deleted."
      refute Repo.get(UserBan, ban.id)
    end
  end
end
