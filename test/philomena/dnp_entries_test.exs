defmodule Philomena.DnpEntriesTest do
  use Philomena.DataCase

  alias Philomena.DnpEntries

  describe "dnp_entries" do
    alias Philomena.DnpEntries.DnpEntry

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def dnp_entry_fixture(attrs \\ %{}) do
      {:ok, dnp_entry} =
        attrs
        |> Enum.into(@valid_attrs)
        |> DnpEntries.create_dnp_entry()

      dnp_entry
    end

    test "list_dnp_entries/0 returns all dnp_entries" do
      dnp_entry = dnp_entry_fixture()
      assert DnpEntries.list_dnp_entries() == [dnp_entry]
    end

    test "get_dnp_entry!/1 returns the dnp_entry with given id" do
      dnp_entry = dnp_entry_fixture()
      assert DnpEntries.get_dnp_entry!(dnp_entry.id) == dnp_entry
    end

    test "create_dnp_entry/1 with valid data creates a dnp_entry" do
      assert {:ok, %DnpEntry{} = dnp_entry} = DnpEntries.create_dnp_entry(@valid_attrs)
    end

    test "create_dnp_entry/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DnpEntries.create_dnp_entry(@invalid_attrs)
    end

    test "update_dnp_entry/2 with valid data updates the dnp_entry" do
      dnp_entry = dnp_entry_fixture()
      assert {:ok, %DnpEntry{} = dnp_entry} = DnpEntries.update_dnp_entry(dnp_entry, @update_attrs)
    end

    test "update_dnp_entry/2 with invalid data returns error changeset" do
      dnp_entry = dnp_entry_fixture()
      assert {:error, %Ecto.Changeset{}} = DnpEntries.update_dnp_entry(dnp_entry, @invalid_attrs)
      assert dnp_entry == DnpEntries.get_dnp_entry!(dnp_entry.id)
    end

    test "delete_dnp_entry/1 deletes the dnp_entry" do
      dnp_entry = dnp_entry_fixture()
      assert {:ok, %DnpEntry{}} = DnpEntries.delete_dnp_entry(dnp_entry)
      assert_raise Ecto.NoResultsError, fn -> DnpEntries.get_dnp_entry!(dnp_entry.id) end
    end

    test "change_dnp_entry/1 returns a dnp_entry changeset" do
      dnp_entry = dnp_entry_fixture()
      assert %Ecto.Changeset{} = DnpEntries.change_dnp_entry(dnp_entry)
    end
  end
end
