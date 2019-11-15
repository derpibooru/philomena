defmodule Philomena.UserNameChangesTest do
  use Philomena.DataCase

  alias Philomena.UserNameChanges

  describe "user_name_changes" do
    alias Philomena.UserNameChanges.UserNameChange

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def user_name_change_fixture(attrs \\ %{}) do
      {:ok, user_name_change} =
        attrs
        |> Enum.into(@valid_attrs)
        |> UserNameChanges.create_user_name_change()

      user_name_change
    end

    test "list_user_name_changes/0 returns all user_name_changes" do
      user_name_change = user_name_change_fixture()
      assert UserNameChanges.list_user_name_changes() == [user_name_change]
    end

    test "get_user_name_change!/1 returns the user_name_change with given id" do
      user_name_change = user_name_change_fixture()
      assert UserNameChanges.get_user_name_change!(user_name_change.id) == user_name_change
    end

    test "create_user_name_change/1 with valid data creates a user_name_change" do
      assert {:ok, %UserNameChange{} = user_name_change} = UserNameChanges.create_user_name_change(@valid_attrs)
    end

    test "create_user_name_change/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = UserNameChanges.create_user_name_change(@invalid_attrs)
    end

    test "update_user_name_change/2 with valid data updates the user_name_change" do
      user_name_change = user_name_change_fixture()
      assert {:ok, %UserNameChange{} = user_name_change} = UserNameChanges.update_user_name_change(user_name_change, @update_attrs)
    end

    test "update_user_name_change/2 with invalid data returns error changeset" do
      user_name_change = user_name_change_fixture()
      assert {:error, %Ecto.Changeset{}} = UserNameChanges.update_user_name_change(user_name_change, @invalid_attrs)
      assert user_name_change == UserNameChanges.get_user_name_change!(user_name_change.id)
    end

    test "delete_user_name_change/1 deletes the user_name_change" do
      user_name_change = user_name_change_fixture()
      assert {:ok, %UserNameChange{}} = UserNameChanges.delete_user_name_change(user_name_change)
      assert_raise Ecto.NoResultsError, fn -> UserNameChanges.get_user_name_change!(user_name_change.id) end
    end

    test "change_user_name_change/1 returns a user_name_change changeset" do
      user_name_change = user_name_change_fixture()
      assert %Ecto.Changeset{} = UserNameChanges.change_user_name_change(user_name_change)
    end
  end
end
