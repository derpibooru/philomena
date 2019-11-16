defmodule Philomena.TagChangesTest do
  use Philomena.DataCase

  alias Philomena.TagChanges

  describe "tag_changes" do
    alias Philomena.TagChanges.TagChange

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def tag_change_fixture(attrs \\ %{}) do
      {:ok, tag_change} =
        attrs
        |> Enum.into(@valid_attrs)
        |> TagChanges.create_tag_change()

      tag_change
    end

    test "list_tag_changes/0 returns all tag_changes" do
      tag_change = tag_change_fixture()
      assert TagChanges.list_tag_changes() == [tag_change]
    end

    test "get_tag_change!/1 returns the tag_change with given id" do
      tag_change = tag_change_fixture()
      assert TagChanges.get_tag_change!(tag_change.id) == tag_change
    end

    test "create_tag_change/1 with valid data creates a tag_change" do
      assert {:ok, %TagChange{} = tag_change} = TagChanges.create_tag_change(@valid_attrs)
    end

    test "create_tag_change/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = TagChanges.create_tag_change(@invalid_attrs)
    end

    test "update_tag_change/2 with valid data updates the tag_change" do
      tag_change = tag_change_fixture()
      assert {:ok, %TagChange{} = tag_change} = TagChanges.update_tag_change(tag_change, @update_attrs)
    end

    test "update_tag_change/2 with invalid data returns error changeset" do
      tag_change = tag_change_fixture()
      assert {:error, %Ecto.Changeset{}} = TagChanges.update_tag_change(tag_change, @invalid_attrs)
      assert tag_change == TagChanges.get_tag_change!(tag_change.id)
    end

    test "delete_tag_change/1 deletes the tag_change" do
      tag_change = tag_change_fixture()
      assert {:ok, %TagChange{}} = TagChanges.delete_tag_change(tag_change)
      assert_raise Ecto.NoResultsError, fn -> TagChanges.get_tag_change!(tag_change.id) end
    end

    test "change_tag_change/1 returns a tag_change changeset" do
      tag_change = tag_change_fixture()
      assert %Ecto.Changeset{} = TagChanges.change_tag_change(tag_change)
    end
  end
end
