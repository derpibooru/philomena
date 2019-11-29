defmodule Philomena.StaticPagesTest do
  use Philomena.DataCase

  alias Philomena.StaticPages

  describe "static_pages" do
    alias Philomena.StaticPages.StaticPage

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def static_page_fixture(attrs \\ %{}) do
      {:ok, static_page} =
        attrs
        |> Enum.into(@valid_attrs)
        |> StaticPages.create_static_page()

      static_page
    end

    test "list_static_pages/0 returns all static_pages" do
      static_page = static_page_fixture()
      assert StaticPages.list_static_pages() == [static_page]
    end

    test "get_static_page!/1 returns the static_page with given id" do
      static_page = static_page_fixture()
      assert StaticPages.get_static_page!(static_page.id) == static_page
    end

    test "create_static_page/1 with valid data creates a static_page" do
      assert {:ok, %StaticPage{} = static_page} = StaticPages.create_static_page(@valid_attrs)
    end

    test "create_static_page/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = StaticPages.create_static_page(@invalid_attrs)
    end

    test "update_static_page/2 with valid data updates the static_page" do
      static_page = static_page_fixture()
      assert {:ok, %StaticPage{} = static_page} = StaticPages.update_static_page(static_page, @update_attrs)
    end

    test "update_static_page/2 with invalid data returns error changeset" do
      static_page = static_page_fixture()
      assert {:error, %Ecto.Changeset{}} = StaticPages.update_static_page(static_page, @invalid_attrs)
      assert static_page == StaticPages.get_static_page!(static_page.id)
    end

    test "delete_static_page/1 deletes the static_page" do
      static_page = static_page_fixture()
      assert {:ok, %StaticPage{}} = StaticPages.delete_static_page(static_page)
      assert_raise Ecto.NoResultsError, fn -> StaticPages.get_static_page!(static_page.id) end
    end

    test "change_static_page/1 returns a static_page changeset" do
      static_page = static_page_fixture()
      assert %Ecto.Changeset{} = StaticPages.change_static_page(static_page)
    end
  end
end
