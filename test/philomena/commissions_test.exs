defmodule Philomena.CommissionsTest do
  use Philomena.DataCase

  alias Philomena.Commissions

  describe "commissions" do
    alias Philomena.Commissions.Commission

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def commission_fixture(attrs \\ %{}) do
      {:ok, commission} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Commissions.create_commission()

      commission
    end

    test "list_commissions/0 returns all commissions" do
      commission = commission_fixture()
      assert Commissions.list_commissions() == [commission]
    end

    test "get_commission!/1 returns the commission with given id" do
      commission = commission_fixture()
      assert Commissions.get_commission!(commission.id) == commission
    end

    test "create_commission/1 with valid data creates a commission" do
      assert {:ok, %Commission{} = commission} = Commissions.create_commission(@valid_attrs)
    end

    test "create_commission/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Commissions.create_commission(@invalid_attrs)
    end

    test "update_commission/2 with valid data updates the commission" do
      commission = commission_fixture()

      assert {:ok, %Commission{} = commission} =
               Commissions.update_commission(commission, @update_attrs)
    end

    test "update_commission/2 with invalid data returns error changeset" do
      commission = commission_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Commissions.update_commission(commission, @invalid_attrs)

      assert commission == Commissions.get_commission!(commission.id)
    end

    test "delete_commission/1 deletes the commission" do
      commission = commission_fixture()
      assert {:ok, %Commission{}} = Commissions.delete_commission(commission)
      assert_raise Ecto.NoResultsError, fn -> Commissions.get_commission!(commission.id) end
    end

    test "change_commission/1 returns a commission changeset" do
      commission = commission_fixture()
      assert %Ecto.Changeset{} = Commissions.change_commission(commission)
    end
  end

  describe "commission_items" do
    alias Philomena.Commissions.Item

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def item_fixture(attrs \\ %{}) do
      {:ok, item} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Commissions.create_item()

      item
    end

    test "list_commission_items/0 returns all commission_items" do
      item = item_fixture()
      assert Commissions.list_commission_items() == [item]
    end

    test "get_item!/1 returns the item with given id" do
      item = item_fixture()
      assert Commissions.get_item!(item.id) == item
    end

    test "create_item/1 with valid data creates a item" do
      assert {:ok, %Item{} = item} = Commissions.create_item(@valid_attrs)
    end

    test "create_item/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Commissions.create_item(@invalid_attrs)
    end

    test "update_item/2 with valid data updates the item" do
      item = item_fixture()
      assert {:ok, %Item{} = item} = Commissions.update_item(item, @update_attrs)
    end

    test "update_item/2 with invalid data returns error changeset" do
      item = item_fixture()
      assert {:error, %Ecto.Changeset{}} = Commissions.update_item(item, @invalid_attrs)
      assert item == Commissions.get_item!(item.id)
    end

    test "delete_item/1 deletes the item" do
      item = item_fixture()
      assert {:ok, %Item{}} = Commissions.delete_item(item)
      assert_raise Ecto.NoResultsError, fn -> Commissions.get_item!(item.id) end
    end

    test "change_item/1 returns a item changeset" do
      item = item_fixture()
      assert %Ecto.Changeset{} = Commissions.change_item(item)
    end
  end
end
