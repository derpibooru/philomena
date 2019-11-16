defmodule Philomena.SourceChangesTest do
  use Philomena.DataCase

  alias Philomena.SourceChanges

  describe "source_changes" do
    alias Philomena.SourceChanges.SourceChange

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def source_change_fixture(attrs \\ %{}) do
      {:ok, source_change} =
        attrs
        |> Enum.into(@valid_attrs)
        |> SourceChanges.create_source_change()

      source_change
    end

    test "list_source_changes/0 returns all source_changes" do
      source_change = source_change_fixture()
      assert SourceChanges.list_source_changes() == [source_change]
    end

    test "get_source_change!/1 returns the source_change with given id" do
      source_change = source_change_fixture()
      assert SourceChanges.get_source_change!(source_change.id) == source_change
    end

    test "create_source_change/1 with valid data creates a source_change" do
      assert {:ok, %SourceChange{} = source_change} = SourceChanges.create_source_change(@valid_attrs)
    end

    test "create_source_change/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = SourceChanges.create_source_change(@invalid_attrs)
    end

    test "update_source_change/2 with valid data updates the source_change" do
      source_change = source_change_fixture()
      assert {:ok, %SourceChange{} = source_change} = SourceChanges.update_source_change(source_change, @update_attrs)
    end

    test "update_source_change/2 with invalid data returns error changeset" do
      source_change = source_change_fixture()
      assert {:error, %Ecto.Changeset{}} = SourceChanges.update_source_change(source_change, @invalid_attrs)
      assert source_change == SourceChanges.get_source_change!(source_change.id)
    end

    test "delete_source_change/1 deletes the source_change" do
      source_change = source_change_fixture()
      assert {:ok, %SourceChange{}} = SourceChanges.delete_source_change(source_change)
      assert_raise Ecto.NoResultsError, fn -> SourceChanges.get_source_change!(source_change.id) end
    end

    test "change_source_change/1 returns a source_change changeset" do
      source_change = source_change_fixture()
      assert %Ecto.Changeset{} = SourceChanges.change_source_change(source_change)
    end
  end
end
