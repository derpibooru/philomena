defmodule Philomena.ModNotesTest do
  use Philomena.DataCase

  alias Philomena.ModNotes

  describe "mod_notes" do
    alias Philomena.ModNotes.ModNote

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def mod_note_fixture(attrs \\ %{}) do
      {:ok, mod_note} =
        attrs
        |> Enum.into(@valid_attrs)
        |> ModNotes.create_mod_note()

      mod_note
    end

    test "list_mod_notes/0 returns all mod_notes" do
      mod_note = mod_note_fixture()
      assert ModNotes.list_mod_notes() == [mod_note]
    end

    test "get_mod_note!/1 returns the mod_note with given id" do
      mod_note = mod_note_fixture()
      assert ModNotes.get_mod_note!(mod_note.id) == mod_note
    end

    test "create_mod_note/1 with valid data creates a mod_note" do
      assert {:ok, %ModNote{} = mod_note} = ModNotes.create_mod_note(@valid_attrs)
    end

    test "create_mod_note/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = ModNotes.create_mod_note(@invalid_attrs)
    end

    test "update_mod_note/2 with valid data updates the mod_note" do
      mod_note = mod_note_fixture()
      assert {:ok, %ModNote{} = mod_note} = ModNotes.update_mod_note(mod_note, @update_attrs)
    end

    test "update_mod_note/2 with invalid data returns error changeset" do
      mod_note = mod_note_fixture()
      assert {:error, %Ecto.Changeset{}} = ModNotes.update_mod_note(mod_note, @invalid_attrs)
      assert mod_note == ModNotes.get_mod_note!(mod_note.id)
    end

    test "delete_mod_note/1 deletes the mod_note" do
      mod_note = mod_note_fixture()
      assert {:ok, %ModNote{}} = ModNotes.delete_mod_note(mod_note)
      assert_raise Ecto.NoResultsError, fn -> ModNotes.get_mod_note!(mod_note.id) end
    end

    test "change_mod_note/1 returns a mod_note changeset" do
      mod_note = mod_note_fixture()
      assert %Ecto.Changeset{} = ModNotes.change_mod_note(mod_note)
    end
  end
end
