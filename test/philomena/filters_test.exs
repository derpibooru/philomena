defmodule Philomena.FiltersTest do
  use Philomena.DataCase

  alias Philomena.Filters

  describe "filters" do
    alias Philomena.Filters.Filter

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def filter_fixture(attrs \\ %{}) do
      {:ok, filter} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Filters.create_filter()

      filter
    end

    test "list_filters/0 returns all filters" do
      filter = filter_fixture()
      assert Filters.list_filters() == [filter]
    end

    test "get_filter!/1 returns the filter with given id" do
      filter = filter_fixture()
      assert Filters.get_filter!(filter.id) == filter
    end

    test "create_filter/1 with valid data creates a filter" do
      assert {:ok, %Filter{} = filter} = Filters.create_filter(@valid_attrs)
    end

    test "create_filter/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Filters.create_filter(@invalid_attrs)
    end

    test "update_filter/2 with valid data updates the filter" do
      filter = filter_fixture()
      assert {:ok, %Filter{} = filter} = Filters.update_filter(filter, @update_attrs)
    end

    test "update_filter/2 with invalid data returns error changeset" do
      filter = filter_fixture()
      assert {:error, %Ecto.Changeset{}} = Filters.update_filter(filter, @invalid_attrs)
      assert filter == Filters.get_filter!(filter.id)
    end

    test "delete_filter/1 deletes the filter" do
      filter = filter_fixture()
      assert {:ok, %Filter{}} = Filters.delete_filter(filter)
      assert_raise Ecto.NoResultsError, fn -> Filters.get_filter!(filter.id) end
    end

    test "change_filter/1 returns a filter changeset" do
      filter = filter_fixture()
      assert %Ecto.Changeset{} = Filters.change_filter(filter)
    end
  end
end
