defmodule Philomena.UserLinksTest do
  use Philomena.DataCase

  alias Philomena.UserLinks

  describe "user_links" do
    alias Philomena.UserLinks.UserLink

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def user_link_fixture(attrs \\ %{}) do
      {:ok, user_link} =
        attrs
        |> Enum.into(@valid_attrs)
        |> UserLinks.create_user_link()

      user_link
    end

    test "list_user_links/0 returns all user_links" do
      user_link = user_link_fixture()
      assert UserLinks.list_user_links() == [user_link]
    end

    test "get_user_link!/1 returns the user_link with given id" do
      user_link = user_link_fixture()
      assert UserLinks.get_user_link!(user_link.id) == user_link
    end

    test "create_user_link/1 with valid data creates a user_link" do
      assert {:ok, %UserLink{} = user_link} = UserLinks.create_user_link(@valid_attrs)
    end

    test "create_user_link/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = UserLinks.create_user_link(@invalid_attrs)
    end

    test "update_user_link/2 with valid data updates the user_link" do
      user_link = user_link_fixture()
      assert {:ok, %UserLink{} = user_link} = UserLinks.update_user_link(user_link, @update_attrs)
    end

    test "update_user_link/2 with invalid data returns error changeset" do
      user_link = user_link_fixture()
      assert {:error, %Ecto.Changeset{}} = UserLinks.update_user_link(user_link, @invalid_attrs)
      assert user_link == UserLinks.get_user_link!(user_link.id)
    end

    test "delete_user_link/1 deletes the user_link" do
      user_link = user_link_fixture()
      assert {:ok, %UserLink{}} = UserLinks.delete_user_link(user_link)
      assert_raise Ecto.NoResultsError, fn -> UserLinks.get_user_link!(user_link.id) end
    end

    test "change_user_link/1 returns a user_link changeset" do
      user_link = user_link_fixture()
      assert %Ecto.Changeset{} = UserLinks.change_user_link(user_link)
    end
  end
end
