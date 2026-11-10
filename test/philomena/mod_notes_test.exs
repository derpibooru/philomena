defmodule Philomena.ModNotesTest do
  @moduledoc """
  Context-level tests for the controller-facing `Philomena.ModNotes` functions:
  the admin index (`load_mod_note_index/4`), the new/create form and insert
  (`new_mod_note/2`, `create_mod_note/2`), and the edit/update/delete actions.

  These pin the staff authorization matrix (assistants and moderators may index,
  create, and touch their own notes; a moderator may not touch another
  moderator's note; an admin may touch any), the moderator attribution on
  create, the notable-filter branch of the index, and uniform not-found results
  for absent IDs.
  """

  use Philomena.DataCase, async: true

  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1, actor: 2]
  import Philomena.DnpEntriesFixtures
  import Philomena.ModNotesFixtures
  import Philomena.ReportsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures
  import Philomena.TagsFixtures

  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.ModNotes
  alias Philomena.ModNotes.ModNote

  @pagination [page: 1, page_size: 25]

  # Note params in the shape the admin form posts.
  defp note_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      "user_id" => confirmed_user_fixture().id,
      "body" => "Watching this one"
    })
  end

  describe "list_mod_notes/4" do
    test "an anonymous viewer is unauthorized" do
      assert ModNotes.list_mod_notes(actor(), %{}, & &1, @pagination) ==
               {:error, :unauthorized}
    end

    test "a regular user is unauthorized" do
      assert ModNotes.list_mod_notes(actor(confirmed_user_fixture()), %{}, & &1, @pagination) ==
               {:error, :unauthorized}
    end

    test "an assistant, a moderator, and an admin are all authorized" do
      for user <- [assistant_user_fixture(), moderator_user_fixture(), admin_user_fixture()] do
        assert {:ok, page} = ModNotes.list_mod_notes(actor(user), %{}, & &1, @pagination)
        assert %Scrivener.Page{} = page
      end
    end

    test "the default view lists all notes newest first as {note, rendered} tuples" do
      moderator = moderator_user_fixture()
      note = mod_note_fixture(moderator)

      assert {:ok, page} = ModNotes.list_mod_notes(actor(moderator), %{}, & &1, @pagination)

      # The identity renderer pairs each note with itself.
      assert note.id in Enum.map(page.entries, fn {loaded, _rendered} -> loaded.id end)
    end

    test "the notable filter restricts to the matching notable" do
      moderator = moderator_user_fixture()
      wanted = mod_note_fixture(moderator)
      other = mod_note_fixture(moderator)

      assert {:ok, page} =
               ModNotes.list_mod_notes(
                 actor(moderator),
                 %{"user_id" => wanted.user_id},
                 & &1,
                 @pagination
               )

      ids = Enum.map(page.entries, fn {loaded, _rendered} -> loaded.id end)
      assert wanted.id in ids
      refute other.id in ids
    end

    test "target filters ignore malformed, missing, and multiple targets" do
      moderator = actor(moderator_user_fixture())
      target = confirmed_user_fixture()

      {:ok, index} =
        ModNotes.list_mod_notes(
          moderator,
          %{"user_id" => "not-an-id"},
          & &1,
          @pagination
        )

      assert Enum.empty?(index)

      {:ok, index} =
        ModNotes.list_mod_notes(
          moderator,
          %{"user_id" => "not-an-id"},
          & &1,
          @pagination
        )

      assert Enum.empty?(index)

      {:ok, index} =
        ModNotes.list_mod_notes(
          moderator,
          %{"user_id" => "2147483647"},
          & &1,
          @pagination
        )

      assert Enum.empty?(index)

      {:ok, index} =
        ModNotes.list_mod_notes(
          moderator,
          %{"user_id" => target.id, "report_id" => "2147483647"},
          & &1,
          @pagination
        )

      assert Enum.empty?(index)
    end
  end

  describe "list_for_target/3" do
    test "loads each supported target kind newest first" do
      author = moderator_user_fixture()
      user = confirmed_user_fixture()
      report = report_fixture(image_id: image_fixture().id)
      dnp_entry = dnp_entry_fixture(confirmed_user_fixture(), tag_fixture())

      {:ok, user_note} =
        ModNotes.create_mod_note(actor(author), %{"body" => "user note", "user_id" => user.id})

      {:ok, report_note} =
        ModNotes.create_mod_note(actor(author), %{
          "body" => "report note",
          "report_id" => report.id
        })

      {:ok, dnp_note} =
        ModNotes.create_mod_note(actor(author), %{
          "body" => "dnp note",
          "dnp_entry_id" => dnp_entry.id
        })

      renderer = fn notes -> Enum.map(notes, & &1.body) end

      assert {:ok, [{loaded, "user note"}]} =
               ModNotes.list_for_target(actor(author), {:user, user.id}, renderer)

      assert loaded.id == user_note.id

      assert {:ok, [{loaded, "report note"}]} =
               ModNotes.list_for_target(actor(author), {:report, report.id}, renderer)

      assert loaded.id == report_note.id

      assert {:ok, [{loaded, "dnp note"}]} =
               ModNotes.list_for_target(actor(author), {:dnp_entry, dnp_entry.id}, renderer)

      assert loaded.id == dnp_note.id
    end

    test "rejects unauthorized viewers and missing target IDs" do
      target = confirmed_user_fixture()
      renderer = fn notes -> notes end

      assert ModNotes.list_for_target(
               actor(confirmed_user_fixture()),
               {:user, target.id},
               renderer
             ) == {:error, :unauthorized}

      assert ModNotes.list_for_target(
               actor(moderator_user_fixture()),
               {:user, "2147483647"},
               renderer
             ) == {:error, :not_found}

      assert ModNotes.list_for_target(
               actor(moderator_user_fixture()),
               {:user, "not-an-id"},
               renderer
             ) == {:error, :not_found}
    end
  end

  describe "new_mod_note/2" do
    test "a moderator gets a changeset seeded from the params" do
      report = report_fixture(image_id: image_fixture().id)

      assert {:ok, changeset} =
               ModNotes.new_mod_note(actor(moderator_user_fixture()), %{
                 "report_id" => to_string(report.id)
               })

      assert Ecto.Changeset.get_field(changeset, :report_id) == report.id
    end

    test "an assistant is authorized" do
      author = assistant_user_fixture()

      assert {:ok, _changeset} =
               ModNotes.new_mod_note(actor(author), %{"user_id" => author.id})
    end

    test "a regular user is unauthorized" do
      assert ModNotes.new_mod_note(actor(confirmed_user_fixture()), %{}) ==
               {:error, :unauthorized}
    end

    test "an anonymous actor is unauthorized" do
      assert ModNotes.new_mod_note(actor(), %{}) == {:error, :unauthorized}
    end

    test "a malformed or missing selected target is not found" do
      moderator = actor(moderator_user_fixture())

      assert ModNotes.new_mod_note(moderator, %{"user_id" => "not-an-id"}) ==
               {:error, :not_found}

      assert ModNotes.new_mod_note(moderator, %{"user_id" => "2147483647"}) ==
               {:error, :not_found}
    end
  end

  describe "create_mod_note/2" do
    test "a moderator creates a note attributed to themselves" do
      moderator = moderator_user_fixture()

      assert {:ok, %ModNote{} = note} = ModNotes.create_mod_note(actor(moderator), note_attrs())
      assert note.moderator_id == moderator.id
      assert note.body == "Watching this one"

      assert %ModerationLog{user_id: user_id, type: "ModNote:create"} =
               Repo.get_by!(ModerationLog, subject_path: "/admin/mod_notes")

      assert user_id == moderator.id
    end

    test "an assistant creates a note" do
      assistant = assistant_user_fixture()

      assert {:ok, %ModNote{} = note} = ModNotes.create_mod_note(actor(assistant), note_attrs())
      assert note.moderator_id == assistant.id
    end

    test "a regular user is unauthorized" do
      assert ModNotes.create_mod_note(actor(confirmed_user_fixture()), note_attrs()) ==
               {:error, :unauthorized}
    end

    test "an anonymous actor is unauthorized" do
      assert ModNotes.create_mod_note(actor(), note_attrs()) == {:error, :unauthorized}
    end

    test "a blank body is a rejected changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               ModNotes.create_mod_note(
                 actor(moderator_user_fixture()),
                 note_attrs(%{"body" => ""})
               )

      assert %{body: ["can't be blank"]} = errors_on(changeset)
      refute Repo.get_by(ModerationLog, type: "ModNote:create")
    end

    test "a missing target is not found without attempting the insert" do
      assert ModNotes.create_mod_note(actor(moderator_user_fixture()), %{
               "body" => "missing target",
               "user_id" => "2147483647"
             }) == {:error, :not_found}

      refute Repo.get_by(ModNote, body: "missing target")
    end

    test "the global write prerequisite rejects banned and unattributed actors" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()
      attrs = %{"body" => "blocked", "user_id" => target.id}

      assert ModNotes.create_mod_note(actor(moderator, ban: %{}), attrs) == {:error, :ban}

      assert ModNotes.create_mod_note(actor(moderator, fingerprint: nil), attrs) ==
               {:error, :unauthorized}

      refute Repo.get_by(ModNote, body: "blocked")
    end
  end

  describe "edit_mod_note/2" do
    test "a moderator loads their own note with a changeset" do
      moderator = moderator_user_fixture()
      note = mod_note_fixture(moderator)

      assert {:ok, {loaded, %Ecto.Changeset{}}} =
               ModNotes.edit_mod_note(actor(moderator), to_string(note.id))

      assert loaded.id == note.id
    end

    test "a moderator may not edit another moderator's note" do
      note = mod_note_fixture(moderator_user_fixture())

      assert ModNotes.edit_mod_note(actor(moderator_user_fixture()), to_string(note.id)) ==
               {:error, :unauthorized}
    end

    test "an admin may edit any note" do
      note = mod_note_fixture(moderator_user_fixture())

      assert {:ok, {loaded, %Ecto.Changeset{}}} =
               ModNotes.edit_mod_note(actor(admin_user_fixture()), to_string(note.id))

      assert loaded.id == note.id
    end

    test "a regular user is unauthorized" do
      note = mod_note_fixture(moderator_user_fixture())

      assert ModNotes.edit_mod_note(actor(confirmed_user_fixture()), to_string(note.id)) ==
               {:error, :unauthorized}
    end

    test "an unknown well-formed id is not-found for every actor" do
      assert ModNotes.edit_mod_note(actor(moderator_user_fixture()), "2147483647") ==
               {:error, :not_found}

      assert ModNotes.edit_mod_note(actor(admin_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "a non-integer id is not-found" do
      assert ModNotes.edit_mod_note(actor(admin_user_fixture()), "not-a-number") ==
               {:error, :not_found}
    end
  end

  describe "update_mod_note/3" do
    test "a moderator updates their own note" do
      moderator = moderator_user_fixture()
      note = mod_note_fixture(moderator)

      assert {:ok, %ModNote{} = updated} =
               ModNotes.update_mod_note(actor(moderator), to_string(note.id), %{
                 "body" => "Edited body"
               })

      assert updated.body == "Edited body"

      assert Repo.get_by!(ModerationLog, type: "ModNote:update").user_id == moderator.id
    end

    test "an admin updates any note" do
      note = mod_note_fixture(moderator_user_fixture())

      assert {:ok, %ModNote{body: "Edited by admin"}} =
               ModNotes.update_mod_note(actor(admin_user_fixture()), to_string(note.id), %{
                 "body" => "Edited by admin"
               })
    end

    test "an invalid update is a rejected changeset" do
      moderator = moderator_user_fixture()
      note = mod_note_fixture(moderator)

      assert {:error, %Ecto.Changeset{} = changeset} =
               ModNotes.update_mod_note(actor(moderator), to_string(note.id), %{"body" => ""})

      assert %{body: ["can't be blank"]} = errors_on(changeset)
      refute Repo.get_by(ModerationLog, type: "ModNote:update")
    end

    test "a moderator may not update another moderator's note" do
      note = mod_note_fixture(moderator_user_fixture())

      assert ModNotes.update_mod_note(actor(moderator_user_fixture()), to_string(note.id), %{
               "body" => "Edited body"
             }) == {:error, :unauthorized}
    end

    test "a regular user is unauthorized" do
      note = mod_note_fixture(moderator_user_fixture())

      assert ModNotes.update_mod_note(actor(confirmed_user_fixture()), to_string(note.id), %{
               "body" => "Edited body"
             }) == {:error, :unauthorized}
    end

    test "an unknown well-formed id is not-found for every actor" do
      assert ModNotes.update_mod_note(actor(moderator_user_fixture()), "2147483647", %{
               "body" => "x"
             }) ==
               {:error, :not_found}

      assert ModNotes.update_mod_note(actor(admin_user_fixture()), "2147483647", %{"body" => "x"}) ==
               {:error, :not_found}
    end

    test "a non-integer id is not-found" do
      assert ModNotes.update_mod_note(actor(admin_user_fixture()), "not-a-number", %{
               "body" => "x"
             }) ==
               {:error, :not_found}
    end
  end

  describe "delete_mod_note/2" do
    test "a moderator deletes their own note" do
      moderator = moderator_user_fixture()
      note = mod_note_fixture(moderator)

      assert {:ok, %ModNote{}} = ModNotes.delete_mod_note(actor(moderator), to_string(note.id))
      refute Repo.get(ModNote, note.id)

      assert Repo.get_by!(ModerationLog, type: "ModNote:delete").user_id == moderator.id
    end

    test "an admin deletes any note" do
      note = mod_note_fixture(moderator_user_fixture())

      assert {:ok, %ModNote{}} =
               ModNotes.delete_mod_note(actor(admin_user_fixture()), to_string(note.id))

      refute Repo.get(ModNote, note.id)
    end

    test "a moderator may not delete another moderator's note" do
      note = mod_note_fixture(moderator_user_fixture())

      assert ModNotes.delete_mod_note(actor(moderator_user_fixture()), to_string(note.id)) ==
               {:error, :unauthorized}

      assert Repo.get(ModNote, note.id)
    end

    test "a regular user is unauthorized" do
      note = mod_note_fixture(moderator_user_fixture())

      assert ModNotes.delete_mod_note(actor(confirmed_user_fixture()), to_string(note.id)) ==
               {:error, :unauthorized}
    end

    test "an unknown well-formed id is not-found for every actor" do
      assert ModNotes.delete_mod_note(actor(moderator_user_fixture()), "2147483647") ==
               {:error, :not_found}

      assert ModNotes.delete_mod_note(actor(admin_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "a non-integer id is not-found" do
      assert ModNotes.delete_mod_note(actor(admin_user_fixture()), "not-a-number") ==
               {:error, :not_found}
    end
  end

  describe "create_mod_note/2 against a target column" do
    test "a user_id note sets user_id" do
      author = moderator_user_fixture()
      target = confirmed_user_fixture()

      {:ok, note} =
        ModNotes.create_mod_note(actor(author), %{"body" => "watching", "user_id" => target.id})

      assert note.user_id == target.id
      assert note.report_id == nil
      assert note.dnp_entry_id == nil
    end

    test "a report_id note sets report_id" do
      author = moderator_user_fixture()
      image = image_fixture()
      report = report_fixture(image_id: image.id)

      {:ok, note} =
        ModNotes.create_mod_note(actor(author), %{
          "body" => "watching report",
          "report_id" => report.id
        })

      assert note.report_id == report.id
      assert note.user_id == nil
    end

    test "a dnp_entry_id note sets dnp_entry_id" do
      author = moderator_user_fixture()
      requester = confirmed_user_fixture()
      tag = tag_fixture()
      dnp_entry = dnp_entry_fixture(requester, tag)

      {:ok, note} =
        ModNotes.create_mod_note(actor(author), %{
          "body" => "watching dnp",
          "dnp_entry_id" => dnp_entry.id
        })

      assert note.dnp_entry_id == dnp_entry.id
      assert note.user_id == nil
    end
  end

  describe "create_mod_note/2 validation" do
    test "rejects a note with no target" do
      author = moderator_user_fixture()

      assert {:error, :not_found} =
               ModNotes.create_mod_note(actor(author), %{"body" => "orphan attempt"})

      refute Repo.get_by(ModNote, body: "orphan attempt")
    end

    test "rejects two targets instead of silently choosing one" do
      author = moderator_user_fixture()
      target = confirmed_user_fixture()
      image = image_fixture()
      report = report_fixture(image_id: image.id)

      assert {:error, :not_found} =
               ModNotes.create_mod_note(actor(author), %{
                 "body" => "two targets",
                 "user_id" => target.id,
                 "report_id" => report.id
               })

      refute Repo.get_by(ModNote, body: "two targets")
    end
  end

  describe "orphaned mod note and DB constraint" do
    setup do
      author = moderator_user_fixture()

      {:ok, orphan} =
        %ModNote{moderator_id: author.id}
        |> Ecto.Changeset.change(%{body: "orphan"})
        |> Repo.insert()

      %{orphan: orphan}
    end

    test "all target columns are nil on an all-NULL note", %{orphan: orphan} do
      assert orphan.user_id == nil
      assert orphan.report_id == nil
      assert orphan.dnp_entry_id == nil
    end

    test "mod_notes_notable_association_null rejects two non-NULL association columns" do
      author = moderator_user_fixture()
      target = confirmed_user_fixture()
      image = image_fixture()
      report = report_fixture(image_id: image.id)

      assert {:error, changeset} =
               %ModNote{moderator_id: author.id}
               |> Ecto.Changeset.change(%{
                 body: "two targets",
                 user_id: target.id,
                 report_id: report.id
               })
               |> Ecto.Changeset.check_constraint(:target,
                 name: "mod_notes_notable_association_null"
               )
               |> Repo.insert()

      assert %{target: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "report-target notes nest the report's target preloads" do
    test "a note on a report about an image can resolve the image" do
      author = moderator_user_fixture()
      owner = confirmed_user_fixture()
      image = image_fixture(%{user_id: owner.id})
      report = report_fixture(image_id: image.id)

      {:ok, _note} =
        ModNotes.create_mod_note(actor(author), %{
          "body" => "note on image report",
          "report_id" => report.id
        })

      assert {:ok, [{note, _body}]} =
               ModNotes.list_for_target(
                 actor(author),
                 {:report, report.id},
                 fn notes -> Enum.map(notes, & &1.body) end
               )

      assert %Philomena.Reports.Report{} = note.report
      assert note.report.id == report.id
      assert note.report.image.id == image.id
      assert note.report.image.user.id == owner.id
    end
  end
end
