defmodule Philomena.UserWhitelistsTest do
  use Philomena.DataCase

  alias Philomena.UserWhitelists

  describe "user_whitelists" do
    alias Philomena.UserWhitelists.UserWhitelist

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def user_whitelist_fixture(attrs \\ %{}) do
      {:ok, user_whitelist} =
        attrs
        |> Enum.into(@valid_attrs)
        |> UserWhitelists.create_user_whitelist()

      user_whitelist
    end

    test "list_user_whitelists/0 returns all user_whitelists" do
      user_whitelist = user_whitelist_fixture()
      assert UserWhitelists.list_user_whitelists() == [user_whitelist]
    end

    test "get_user_whitelist!/1 returns the user_whitelist with given id" do
      user_whitelist = user_whitelist_fixture()
      assert UserWhitelists.get_user_whitelist!(user_whitelist.id) == user_whitelist
    end

    test "create_user_whitelist/1 with valid data creates a user_whitelist" do
      assert {:ok, %UserWhitelist{} = user_whitelist} = UserWhitelists.create_user_whitelist(@valid_attrs)
    end

    test "create_user_whitelist/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = UserWhitelists.create_user_whitelist(@invalid_attrs)
    end

    test "update_user_whitelist/2 with valid data updates the user_whitelist" do
      user_whitelist = user_whitelist_fixture()
      assert {:ok, %UserWhitelist{} = user_whitelist} = UserWhitelists.update_user_whitelist(user_whitelist, @update_attrs)
    end

    test "update_user_whitelist/2 with invalid data returns error changeset" do
      user_whitelist = user_whitelist_fixture()
      assert {:error, %Ecto.Changeset{}} = UserWhitelists.update_user_whitelist(user_whitelist, @invalid_attrs)
      assert user_whitelist == UserWhitelists.get_user_whitelist!(user_whitelist.id)
    end

    test "delete_user_whitelist/1 deletes the user_whitelist" do
      user_whitelist = user_whitelist_fixture()
      assert {:ok, %UserWhitelist{}} = UserWhitelists.delete_user_whitelist(user_whitelist)
      assert_raise Ecto.NoResultsError, fn -> UserWhitelists.get_user_whitelist!(user_whitelist.id) end
    end

    test "change_user_whitelist/1 returns a user_whitelist changeset" do
      user_whitelist = user_whitelist_fixture()
      assert %Ecto.Changeset{} = UserWhitelists.change_user_whitelist(user_whitelist)
    end
  end
end
