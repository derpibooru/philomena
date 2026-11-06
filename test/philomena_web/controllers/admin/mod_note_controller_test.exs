defmodule PhilomenaWeb.Admin.ModNoteControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ModNotesFixtures
  import Philomena.UsersFixtures

  alias Philomena.ModNotes.ModNote
  alias Philomena.Repo

  describe "GET /admin/mod_notes (index) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/mod_notes")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/mod_notes")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/mod_notes")
      assert html_response(conn, 200) =~ "Mod Notes"
    end

    test "allows an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/mod_notes")
      assert html_response(conn, 200) =~ "Mod Notes"
    end
  end

  describe "GET /admin/mod_notes (index) content" do
    setup [:register_and_log_in_admin]

    test "renders the empty index", %{conn: conn} do
      conn = get(conn, ~p"/admin/mod_notes")
      response = html_response(conn, 200)
      assert response =~ "Admin - Mod Notes - Derpibooru"
      assert response =~ "Mod Notes"
    end

    test "lists an existing note", %{conn: conn, user: admin} do
      _note = mod_note_fixture(admin)
      conn = get(conn, ~p"/admin/mod_notes")
      response = html_response(conn, 200)
      assert response =~ "Keeping an eye on this one"
    end

    test "filters by target column, keeping the filter across pages", %{conn: conn, user: admin} do
      note = mod_note_fixture(admin)
      mod_note_fixture_for(admin, %{"user_id" => note.user_id})

      conn = get(conn, ~p"/admin/mod_notes?#{[user_id: note.user_id, per_page: 1]}")

      response = html_response(conn, 200)
      assert response =~ "Keeping an eye on this one"
      assert response =~ "/admin/mod_notes?page=2&amp;user_id=#{note.user_id}"
    end

    # An orphaned note has all columns NULL, as if its target had been
    # deleted (the FK nilify path). Inserted directly since no target exists.
    test "renders an orphaned note with the permanently-deleted fallback", %{
      conn: conn,
      user: admin
    } do
      {:ok, _note} =
        %ModNote{moderator_id: admin.id}
        |> Ecto.Changeset.change(%{body: "Orphaned note body"})
        |> Repo.insert()

      conn = get(conn, ~p"/admin/mod_notes")
      response = html_response(conn, 200)
      assert response =~ "Orphaned note body"
      assert response =~ "Item permanently deleted"
    end
  end

  describe "GET /admin/mod_notes/new" do
    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      target = confirmed_user_fixture()
      conn = get(conn, ~p"/admin/mod_notes/new?#{[user_id: target.id]}")
      assert redirected_to(conn) == "/"
    end

    test "renders the form for a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      target = confirmed_user_fixture()
      conn = get(conn, ~p"/admin/mod_notes/new?#{[user_id: target.id]}")
      response = html_response(conn, 200)
      assert response =~ "New mod note for User #{target.id}"
      refute response =~ "unknown target"
    end

    test "renders the form for an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      target = confirmed_user_fixture()
      conn = get(conn, ~p"/admin/mod_notes/new?#{[user_id: target.id]}")
      response = html_response(conn, 200)
      assert response =~ "New mod note for User #{target.id}"
      refute response =~ "unknown target"
    end

    test "redirects to / with a not-found flash with no id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/admin/mod_notes/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the form for a moderator without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      target = confirmed_user_fixture()
      conn = get(without_fingerprint(conn), ~p"/admin/mod_notes/new?#{[user_id: target.id]}")

      assert html_response(conn, 200) =~ "New mod note for User #{target.id}"
    end
  end

  describe "POST /admin/mod_notes (create)" do
    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      target = confirmed_user_fixture()

      conn =
        post(conn, ~p"/admin/mod_notes", %{
          "mod_note" => %{
            "user_id" => target.id,
            "body" => "nope"
          }
        })

      assert redirected_to(conn) == "/"
      refute Repo.exists?(ModNote)
    end

    test "creates a note as a moderator", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      target = confirmed_user_fixture()

      conn =
        post(conn, ~p"/admin/mod_notes", %{
          "mod_note" => %{
            "user_id" => target.id,
            "body" => "Moderator authored note"
          }
        })

      assert redirected_to(conn) == ~p"/admin/mod_notes"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully created mod note."
      note = Repo.get_by(ModNote, body: "Moderator authored note")
      assert note.moderator_id == mod.id
    end

    test "creates a note as an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      target = confirmed_user_fixture()

      conn =
        post(conn, ~p"/admin/mod_notes", %{
          "mod_note" => %{
            "user_id" => target.id,
            "body" => "Admin authored note"
          }
        })

      assert redirected_to(conn) == ~p"/admin/mod_notes"
      assert Repo.get_by(ModNote, body: "Admin authored note")
    end

    test "re-renders the form on a validation failure", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      target = confirmed_user_fixture()

      conn =
        post(conn, ~p"/admin/mod_notes", %{
          "mod_note" => %{
            "user_id" => target.id,
            "body" => ""
          }
        })

      assert html_response(conn, 200) =~ "New mod note for User #{target.id}"
      refute Repo.exists?(ModNote)
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(without_fingerprint(conn), ~p"/admin/mod_notes", %{
          "mod_note" => %{
            "user_id" => confirmed_user_fixture().id,
            "body" => "Fingerprintless note"
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get_by(ModNote, body: "Fingerprintless note")
    end
  end

  describe "GET /admin/mod_notes/:id/edit" do
    test "rejects a regular user", %{conn: conn} do
      note = mod_note_fixture(admin_user_fixture())
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/mod_notes/#{note}/edit")
      assert redirected_to(conn) == "/"
    end

    test "lets a moderator edit their own note", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      note = mod_note_fixture(mod)
      conn = get(conn, ~p"/admin/mod_notes/#{note}/edit")
      assert html_response(conn, 200) =~ "Editing mod note for"
    end

    # NOTE: The edit/update/delete abilities are scoped to a note's own
    # moderator_id, so a moderator cannot edit another moderator's note.
    test "rejects a moderator editing another moderator's note", %{conn: conn} do
      note = mod_note_fixture(admin_user_fixture())
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/mod_notes/#{note}/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "lets an admin edit any note", %{conn: conn} do
      note = mod_note_fixture(moderator_user_fixture())
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/mod_notes/#{note}/edit")
      assert html_response(conn, 200) =~ "Editing mod note for"
    end

    test "redirects to / with a not-found flash for an unknown id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/mod_notes/#{2_000_000_000}/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects to / with a not-found flash for a non-integer id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/admin/mod_notes/not-a-number/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the edit form for its moderator without a fingerprint", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      note = mod_note_fixture(mod)
      conn = get(without_fingerprint(conn), ~p"/admin/mod_notes/#{note}/edit")

      assert html_response(conn, 200) =~ "Editing mod note for"
    end
  end

  describe "PATCH /admin/mod_notes/:id (update)" do
    test "rejects a moderator updating another moderator's note", %{conn: conn} do
      note = mod_note_fixture(admin_user_fixture())
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = patch(conn, ~p"/admin/mod_notes/#{note}", %{"mod_note" => %{"body" => "changed"}})
      assert redirected_to(conn) == "/"
    end

    test "updates a moderator's own note", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      note = mod_note_fixture(mod)

      conn =
        patch(conn, ~p"/admin/mod_notes/#{note}", %{
          "mod_note" => %{"body" => "Updated note body"}
        })

      assert redirected_to(conn) == ~p"/admin/mod_notes"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully updated mod note."
      assert Repo.get(ModNote, note.id).body == "Updated note body"
    end

    test "re-renders the edit form on a validation failure", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      note = mod_note_fixture(mod)

      conn =
        patch(conn, ~p"/admin/mod_notes/#{note}", %{
          "mod_note" => %{"body" => ""}
        })

      assert html_response(conn, 200) =~ "Editing mod note for"
      assert Repo.get(ModNote, note.id).body == "Keeping an eye on this one"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      note = mod_note_fixture(mod)

      conn =
        patch(without_fingerprint(conn), ~p"/admin/mod_notes/#{note}", %{
          "mod_note" => %{"body" => "Updated note body"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(ModNote, note.id).body == note.body
    end
  end

  describe "PUT /admin/mod_notes/:id (update)" do
    test "updates a note as an admin", %{conn: conn} do
      note = mod_note_fixture(moderator_user_fixture())
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        put(conn, ~p"/admin/mod_notes/#{note}", %{
          "mod_note" => %{"body" => "Put updated note"}
        })

      assert redirected_to(conn) == ~p"/admin/mod_notes"
      assert Repo.get(ModNote, note.id).body == "Put updated note"
    end
  end

  describe "DELETE /admin/mod_notes/:id" do
    test "rejects a moderator deleting another moderator's note", %{conn: conn} do
      note = mod_note_fixture(admin_user_fixture())
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = delete(conn, ~p"/admin/mod_notes/#{note}")
      assert redirected_to(conn) == "/"
      assert Repo.get(ModNote, note.id)
    end

    test "deletes a moderator's own note", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      note = mod_note_fixture(mod)
      conn = delete(conn, ~p"/admin/mod_notes/#{note}")
      assert redirected_to(conn) == ~p"/admin/mod_notes"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully deleted mod note."
      refute Repo.get(ModNote, note.id)
    end

    test "lets an admin delete any note", %{conn: conn} do
      note = mod_note_fixture(moderator_user_fixture())
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = delete(conn, ~p"/admin/mod_notes/#{note}")
      assert redirected_to(conn) == ~p"/admin/mod_notes"
      refute Repo.get(ModNote, note.id)
    end
  end
end
