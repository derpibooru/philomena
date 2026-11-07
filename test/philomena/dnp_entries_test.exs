defmodule Philomena.DnpEntriesTest do
  @moduledoc """
  Context-level tests for the controller-facing `Philomena.DnpEntries` functions.

  These pin the typed listing, page, and form contracts; load-before-authorize
  behavior; action-specific permissions; safe selectable-tag handling; global
  write prerequisites; and transactional staff transitions.
  """

  use Philomena.DataCase, async: true

  import Philomena.AttributionFixtures
  import Philomena.ArtistLinksFixtures
  import Philomena.DnpEntriesFixtures
  import Philomena.ModNotesFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.DnpEntries
  alias Philomena.DnpEntries.{DnpEntry, DnpEntryForm, DnpEntryPage, DnpListing}
  alias Philomena.ModerationLogs.ModerationLog

  # A truthy ban value in the shape production passes; only its presence matters
  # to the write-access and not-banned checks the write paths run first.
  @ban %{
    reason: "Rule #0",
    valid_until: ~U[3000-01-01 00:00:00Z],
    generated_ban_id: "U123456",
    type: "User"
  }

  @pagination [page: 1, page_size: 25]

  defp artist_tag do
    tag_fixture(name: "artist:dnp-test-#{System.unique_integer([:positive])}")
  end

  # A confirmed user holding a verified artist link, so the user has a linked
  # tag to file a DNP request against. Returns {user, tag}.
  defp linked_user do
    user = confirmed_user_fixture()
    tag = artist_tag()
    verified_artist_link_fixture(user, tag)
    {user, tag}
  end

  defp dnp_entry_attrs(tag, attrs \\ %{}) do
    Enum.into(attrs, %{
      "tag_id" => to_string(tag.id),
      "dnp_type" => "No Edits",
      "reason" => "Test DNP reason"
    })
  end

  describe "list_dnp_entries/3" do
    test "the mine listing returns the user's own entries with the status column" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert %DnpListing{status_column: true, dnp_entries: page} =
               DnpEntries.list_dnp_entries(actor(user), %{"mine" => "1"}, @pagination)

      assert entry.id in Enum.map(page.entries, & &1.id)
    end

    test "the default listing returns only listed entries, without the status column" do
      {user, tag} = linked_user()
      listed = dnp_entry_fixture(user, tag, %{state: "listed"})

      {other, other_tag} = linked_user()
      requested = dnp_entry_fixture(other, other_tag)

      assert %DnpListing{status_column: false, dnp_entries: page} =
               DnpEntries.list_dnp_entries(actor(), %{}, @pagination)

      ids = Enum.map(page.entries, & &1.id)
      assert listed.id in ids
      refute requested.id in ids
    end

    test "the viewer's linked tags travel along for the sidebar" do
      {user, tag} = linked_user()

      assert %DnpListing{linked_tags: tags} =
               DnpEntries.list_dnp_entries(actor(user), %{}, @pagination)

      assert tag.id in Enum.map(tags, & &1.id)
    end

    test "an anonymous viewer has no linked tags" do
      assert %DnpListing{linked_tags: []} = DnpEntries.list_dnp_entries(actor(), %{}, @pagination)
    end
  end

  describe "show_dnp_entry/3" do
    test "loads a listed entry for an anonymous viewer, with the tag preloaded" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag, %{state: "listed"})

      assert {:ok, %DnpEntryPage{dnp_entry: loaded}} =
               DnpEntries.show_dnp_entry(actor(), to_string(entry.id), & &1)

      assert loaded.id == entry.id
      refute match?(%Ecto.Association.NotLoaded{}, loaded.tag)
    end

    test "the requesting user may load their own not-yet-listed entry" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert {:ok, %DnpEntryPage{dnp_entry: loaded}} =
               DnpEntries.show_dnp_entry(actor(user), to_string(entry.id), & &1)

      assert loaded.id == entry.id
    end

    test "an unrelated user may not load a still-requested entry" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert DnpEntries.show_dnp_entry(
               actor(confirmed_user_fixture()),
               to_string(entry.id),
               & &1
             ) ==
               {:error, :unauthorized}
    end

    test "an unknown well-formed id is not-found for every signed-in role" do
      assert DnpEntries.show_dnp_entry(
               actor(confirmed_user_fixture()),
               "2147483647",
               & &1
             ) ==
               {:error, :not_found}

      assert DnpEntries.show_dnp_entry(
               actor(moderator_user_fixture()),
               "2147483647",
               & &1
             ) ==
               {:error, :not_found}

      assert DnpEntries.show_dnp_entry(
               actor(admin_user_fixture()),
               "2147483647",
               & &1
             ) ==
               {:error, :not_found}
    end

    test "an unknown well-formed id is not-found for an anonymous viewer" do
      assert DnpEntries.show_dnp_entry(actor(), "2147483647", & &1) ==
               {:error, :not_found}
    end

    test "a non-integer id is not-found" do
      assert DnpEntries.show_dnp_entry(actor(), "not-a-number", & &1) ==
               {:error, :not_found}
    end
  end

  describe "DNP page moderation notes" do
    test "a moderator gets the rendered mod notes for the entry" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      note =
        mod_note_fixture_for(moderator_user_fixture(), %{"dnp_entry_id" => entry.id})

      # The renderer zips each note with its rendered body into a {note, body}
      # tuple, so the identity renderer pairs each note with itself.
      assert {:ok, %DnpEntryPage{mod_notes: notes}} =
               DnpEntries.show_dnp_entry(
                 actor(moderator_user_fixture()),
                 entry.id,
                 & &1
               )

      assert is_list(notes)
      assert note.id in Enum.map(notes, fn {loaded, _body} -> loaded.id end)
    end

    test "an assistant is permitted to read mod notes" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag, %{state: "listed"})

      assert {:ok, %DnpEntryPage{mod_notes: notes}} =
               DnpEntries.show_dnp_entry(actor(assistant_user_fixture()), entry.id, & &1)

      assert is_list(notes)
    end

    test "a regular user gets nil" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert {:ok, %DnpEntryPage{mod_notes: nil}} =
               DnpEntries.show_dnp_entry(actor(user), entry.id, & &1)
    end

    test "an anonymous viewer gets nil" do
      {user, tag} = linked_user()
      listed = dnp_entry_fixture(user, tag, %{state: "listed"})

      assert {:ok, %DnpEntryPage{mod_notes: nil}} =
               DnpEntries.show_dnp_entry(actor(), listed.id, & &1)
    end
  end

  describe "new_dnp_entry/2" do
    test "a user with a linked tag gets a changeset and their selectable tags" do
      {user, tag} = linked_user()

      assert {:ok, %DnpEntryForm{changeset: %Ecto.Changeset{}, selectable_tags: tags}} =
               DnpEntries.new_dnp_entry(actor(user), %{})

      assert tag.id in Enum.map(tags, & &1.id)
    end

    test "a user cannot select arbitrary tags" do
      {user, _tag} = linked_user()
      unlinked_tag = tag_fixture()

      assert {:ok, %DnpEntryForm{selectable_tags: tags}} =
               DnpEntries.new_dnp_entry(actor(user), %{"tag_id" => unlinked_tag.id})

      refute unlinked_tag.id in Enum.map(tags, & &1.id)
    end

    test "a banned actor is rejected before the tag check" do
      {user, _tag} = linked_user()

      assert DnpEntries.new_dnp_entry(actor(user, ban: @ban), %{}) == {:error, :ban}
    end

    test "an actor without a fingerprint still gets the form" do
      {user, _tag} = linked_user()

      assert {:ok, %DnpEntryForm{}} = DnpEntries.new_dnp_entry(actor(user, fingerprint: nil), %{})
    end

    test "an actor with no selectable tag is unauthorized" do
      assert DnpEntries.new_dnp_entry(actor(confirmed_user_fixture()), %{}) ==
               {:error, :unauthorized}
    end

    test "a moderator can select any tag" do
      moderator = actor(moderator_user_fixture())
      tag = tag_fixture()

      assert {:ok, %DnpEntryForm{selectable_tags: tags}} =
               DnpEntries.new_dnp_entry(moderator, %{"tag_id" => tag.id})

      assert tag.id in Enum.map(tags, & &1.id)
    end
  end

  describe "create_dnp_entry/2" do
    test "a user with a linked tag files a request against it" do
      {user, tag} = linked_user()

      assert {:ok, %DnpEntry{} = entry} =
               DnpEntries.create_dnp_entry(actor(user), dnp_entry_attrs(tag))

      assert entry.tag_id == tag.id
      assert entry.requesting_user_id == user.id
    end

    test "a staff member files against arbitrary tags" do
      moderator = moderator_user_fixture()
      tag = artist_tag()

      assert {:ok, %DnpEntry{} = entry} =
               DnpEntries.create_dnp_entry(actor(moderator), dnp_entry_attrs(tag))

      assert entry.tag_id == tag.id
      assert entry.requesting_user_id == moderator.id
    end

    test "a banned actor is rejected" do
      {user, tag} = linked_user()

      assert DnpEntries.create_dnp_entry(actor(user, ban: @ban), dnp_entry_attrs(tag)) ==
               {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized" do
      {user, tag} = linked_user()

      assert DnpEntries.create_dnp_entry(actor(user, fingerprint: nil), dnp_entry_attrs(tag)) ==
               {:error, :unauthorized}
    end

    test "an actor with no selectable tag is unauthorized" do
      assert DnpEntries.create_dnp_entry(actor(confirmed_user_fixture()), %{}) ==
               {:error, :unauthorized}
    end

    test "an invalid request re-renders with the changeset and selectable tags" do
      {user, tag} = linked_user()

      assert {:error,
              %DnpEntryForm{
                dnp_entry: %DnpEntry{},
                changeset: %Ecto.Changeset{} = changeset,
                selectable_tags: tags
              }} =
               DnpEntries.create_dnp_entry(actor(user), dnp_entry_attrs(tag, %{"reason" => ""}))

      refute changeset.valid?
      assert tag.id in Enum.map(tags, & &1.id)
    end

    test "an unoffered tag is preserved as a form changeset error" do
      {user, tag} = linked_user()
      other_tag = artist_tag()

      assert {:error, %DnpEntryForm{changeset: changeset, selectable_tags: [selected]}} =
               DnpEntries.create_dnp_entry(actor(user), dnp_entry_attrs(other_tag))

      assert selected.id == tag.id
      assert %{tag_id: ["must be one of your linked tags"]} = errors_on(changeset)
    end

    test "a moderator's malformed tag is unauthorized" do
      assert {:error, :unauthorized} =
               DnpEntries.create_dnp_entry(actor(moderator_user_fixture()), %{
                 "tag_id" => "not-a-number"
               })
    end
  end

  describe "edit_dnp_entry/2" do
    test "a moderator loads the entry, a changeset, and the selectable tags" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert {:ok,
              %DnpEntryForm{
                dnp_entry: loaded,
                changeset: %Ecto.Changeset{},
                selectable_tags: [_ | _]
              }} =
               DnpEntries.edit_dnp_entry(
                 actor(moderator_user_fixture()),
                 to_string(entry.id)
               )

      assert loaded.id == entry.id
    end

    test "a moderator can load a bare edit URL using the entry's current tag" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert {:ok, %DnpEntryForm{selectable_tags: [selected]}} =
               DnpEntries.edit_dnp_entry(
                 actor(moderator_user_fixture()),
                 entry.id
               )

      assert selected.id == tag.id
    end

    test "a banned moderator cannot load the form" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert DnpEntries.edit_dnp_entry(
               actor(moderator_user_fixture(), ban: @ban),
               entry.id
             ) == {:error, :ban}
    end

    test "a regular user may not edit an entry" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert DnpEntries.edit_dnp_entry(actor(user), to_string(entry.id)) ==
               {:error, :unauthorized}
    end

    test "a non-integer id is not-found" do
      assert DnpEntries.edit_dnp_entry(
               actor(moderator_user_fixture()),
               "not-a-number"
             ) == {:error, :not_found}
    end
  end

  describe "update_dnp_entry/3" do
    test "a moderator updates an entry" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert {:ok, %DnpEntry{}} =
               DnpEntries.update_dnp_entry(
                 actor(moderator_user_fixture()),
                 to_string(entry.id),
                 dnp_entry_attrs(tag, %{"reason" => "Updated reason"})
               )

      assert Repo.reload!(entry).reason == "Updated reason"
    end

    test "an invalid update re-renders with the entry, changeset, and selectable tags" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert {:error,
              %DnpEntryForm{
                dnp_entry: %DnpEntry{},
                changeset: %Ecto.Changeset{} = changeset,
                selectable_tags: [_ | _]
              }} =
               DnpEntries.update_dnp_entry(
                 actor(moderator_user_fixture()),
                 to_string(entry.id),
                 dnp_entry_attrs(tag, %{"reason" => ""})
               )

      refute changeset.valid?
    end

    test "a regular user may not update an entry" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert DnpEntries.update_dnp_entry(actor(user), to_string(entry.id), dnp_entry_attrs(tag)) ==
               {:error, :unauthorized}
    end

    test "a non-integer id is not-found" do
      tag = artist_tag()

      assert DnpEntries.update_dnp_entry(
               actor(moderator_user_fixture()),
               "not-a-number",
               dnp_entry_attrs(tag)
             ) == {:error, :not_found}
    end

    test "an unoffered replacement tag is preserved as a form changeset error" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)
      other_tag = artist_tag()

      assert {:error, %DnpEntryForm{changeset: changeset, selectable_tags: [selected]}} =
               DnpEntries.update_dnp_entry(
                 actor(moderator_user_fixture()),
                 entry.id,
                 dnp_entry_attrs(other_tag)
               )

      assert selected.id == tag.id
      assert %{tag_id: ["must be one of your linked tags"]} = errors_on(changeset)
      assert Repo.reload!(entry).tag_id == tag.id
    end

    test "a banned moderator cannot update" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert DnpEntries.update_dnp_entry(
               actor(moderator_user_fixture(), ban: @ban),
               entry.id,
               %{"dnp_entry" => dnp_entry_attrs(tag)}
             ) == {:error, :ban}
    end
  end

  describe "list_admin_dnp_entries/3" do
    test "an anonymous viewer is unauthorized" do
      assert DnpEntries.list_admin_dnp_entries(actor(), %{}, @pagination) ==
               {:error, :unauthorized}
    end

    test "a regular user is unauthorized" do
      assert DnpEntries.list_admin_dnp_entries(actor(confirmed_user_fixture()), %{}, @pagination) ==
               {:error, :unauthorized}
    end

    test "a moderator and an admin are authorized" do
      for user <- [moderator_user_fixture(), admin_user_fixture()] do
        assert {:ok, %Scrivener.Page{}, %Ecto.Changeset{valid?: true}} =
                 DnpEntries.list_admin_dnp_entries(actor(user), %{}, @pagination)
      end
    end

    test "the default view lists the active states and excludes listed entries" do
      {user, tag} = linked_user()
      requested = dnp_entry_fixture(user, tag)

      {other, other_tag} = linked_user()
      listed = dnp_entry_fixture(other, other_tag, %{state: "listed"})

      assert {:ok, page, %Ecto.Changeset{valid?: true}} =
               DnpEntries.list_admin_dnp_entries(
                 actor(moderator_user_fixture()),
                 %{},
                 @pagination
               )

      ids = Enum.map(page.entries, & &1.id)
      assert requested.id in ids
      refute listed.id in ids
    end

    test "a states list restricts to those states" do
      {user, tag} = linked_user()
      requested = dnp_entry_fixture(user, tag)

      {other, other_tag} = linked_user()
      listed = dnp_entry_fixture(other, other_tag, %{state: "listed"})

      assert {:ok, page, %Ecto.Changeset{valid?: true}} =
               DnpEntries.list_admin_dnp_entries(
                 actor(moderator_user_fixture()),
                 %{"states" => ["listed"]},
                 @pagination
               )

      ids = Enum.map(page.entries, & &1.id)
      assert listed.id in ids
      refute requested.id in ids
    end

    test "a text param filters by the tag name" do
      {user, tag} = linked_user()
      wanted = dnp_entry_fixture(user, tag)

      {other, other_tag} = linked_user()
      unrelated = dnp_entry_fixture(other, other_tag)

      assert {:ok, page, %Ecto.Changeset{valid?: true}} =
               DnpEntries.list_admin_dnp_entries(
                 actor(moderator_user_fixture()),
                 %{"text" => tag.name},
                 @pagination
               )

      ids = Enum.map(page.entries, & &1.id)
      assert wanted.id in ids
      refute unrelated.id in ids
    end

    test "states and text filters are applied together" do
      {user, tag} = linked_user()
      listed_match = dnp_entry_fixture(user, tag, %{state: "listed"})

      {other, other_tag} = linked_user()
      listed_other = dnp_entry_fixture(other, other_tag, %{state: "listed"})

      assert {:ok, page, %Ecto.Changeset{valid?: true}} =
               DnpEntries.list_admin_dnp_entries(
                 actor(moderator_user_fixture()),
                 %{"states" => ["listed"], "text" => tag.name},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [listed_match.id]
      refute listed_other.id in Enum.map(page.entries, & &1.id)
    end
  end

  describe "create_dnp_entry_transition/3" do
    test "accepts every declared DNP state" do
      moderator = actor(moderator_user_fixture())

      for state <- DnpEntry.states() do
        {user, tag} = linked_user()
        entry = dnp_entry_fixture(user, tag)

        assert {:ok, %DnpEntry{aasm_state: ^state}} =
                 DnpEntries.create_dnp_entry_transition(moderator, entry.id, state)
      end
    end

    test "a moderator transitions an entry and writes a moderation log" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)
      moderator = moderator_user_fixture()

      assert {:ok, %DnpEntry{aasm_state: "acknowledged"} = transitioned} =
               DnpEntries.create_dnp_entry_transition(
                 actor(moderator),
                 to_string(entry.id),
                 "acknowledged"
               )

      assert transitioned.id == entry.id

      log = Repo.one!(ModerationLog)
      assert log.user_id == moderator.id
      assert log.type == "Admin.DnpEntry.Transition:create"
      assert log.subject_path == "/dnp/#{entry.id}"
      assert log.body == "Acknowledged DNP entry #{entry.id} on #{tag.name}"
    end

    test "an admin transitions an entry" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert {:ok, %DnpEntry{aasm_state: "rescinded"}} =
               DnpEntries.create_dnp_entry_transition(
                 actor(admin_user_fixture()),
                 to_string(entry.id),
                 "rescinded"
               )
    end

    test "an anonymous actor is unauthorized" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert DnpEntries.create_dnp_entry_transition(actor(), to_string(entry.id), "acknowledged") ==
               {:error, :unauthorized}

      assert Repo.aggregate(ModerationLog, :count) == 0
    end

    test "a regular user is unauthorized" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert DnpEntries.create_dnp_entry_transition(
               actor(confirmed_user_fixture()),
               to_string(entry.id),
               "acknowledged"
             ) == {:error, :unauthorized}

      assert Repo.aggregate(ModerationLog, :count) == 0
    end

    test "an invalid target state is a rejected changeset and writes no log" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert {:error, %Ecto.Changeset{} = changeset} =
               DnpEntries.create_dnp_entry_transition(
                 actor(moderator_user_fixture()),
                 to_string(entry.id),
                 "not-a-state"
               )

      refute changeset.valid?
      assert Repo.aggregate(ModerationLog, :count) == 0
    end

    test "a missing target state is a rejected changeset and writes no log" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert {:error, %Ecto.Changeset{} = changeset} =
               DnpEntries.create_dnp_entry_transition(
                 actor(moderator_user_fixture()),
                 entry.id,
                 nil
               )

      refute changeset.valid?
      assert Repo.aggregate(ModerationLog, :count) == 0
    end

    test "a banned moderator is rejected before the transition" do
      {user, tag} = linked_user()
      entry = dnp_entry_fixture(user, tag)

      assert DnpEntries.create_dnp_entry_transition(
               actor(moderator_user_fixture(), ban: @ban),
               entry.id,
               "claimed"
             ) == {:error, :ban}

      assert Repo.reload!(entry).aasm_state == "requested"
    end

    test "an unknown well-formed id is not-found for an authorized actor" do
      assert DnpEntries.create_dnp_entry_transition(
               actor(moderator_user_fixture()),
               "2147483647",
               "acknowledged"
             ) ==
               {:error, :not_found}
    end

    test "a non-integer id is not-found for an authorized actor" do
      assert DnpEntries.create_dnp_entry_transition(
               actor(moderator_user_fixture()),
               "not-a-number",
               "acknowledged"
             ) == {:error, :not_found}
    end
  end

  describe "count_dnp_entries/1" do
    test "returns active count for a moderator and nil for a regular user" do
      {user, tag} = linked_user()
      _entry = dnp_entry_fixture(user, tag)

      assert DnpEntries.count_dnp_entries(actor(moderator_user_fixture())) == 1
      assert DnpEntries.count_dnp_entries(actor(confirmed_user_fixture())) == nil
    end
  end
end
