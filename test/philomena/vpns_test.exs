defmodule Philomena.VpnsTest do
  use Philomena.DataCase

  alias Philomena.Vpns

  describe "vpns" do
    alias Philomena.Vpns.Vpn

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def vpn_fixture(attrs \\ %{}) do
      {:ok, vpn} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Vpns.create_vpn()

      vpn
    end

    test "list_vpns/0 returns all vpns" do
      vpn = vpn_fixture()
      assert Vpns.list_vpns() == [vpn]
    end

    test "get_vpn!/1 returns the vpn with given id" do
      vpn = vpn_fixture()
      assert Vpns.get_vpn!(vpn.id) == vpn
    end

    test "create_vpn/1 with valid data creates a vpn" do
      assert {:ok, %Vpn{} = vpn} = Vpns.create_vpn(@valid_attrs)
    end

    test "create_vpn/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Vpns.create_vpn(@invalid_attrs)
    end

    test "update_vpn/2 with valid data updates the vpn" do
      vpn = vpn_fixture()
      assert {:ok, %Vpn{} = vpn} = Vpns.update_vpn(vpn, @update_attrs)
    end

    test "update_vpn/2 with invalid data returns error changeset" do
      vpn = vpn_fixture()
      assert {:error, %Ecto.Changeset{}} = Vpns.update_vpn(vpn, @invalid_attrs)
      assert vpn == Vpns.get_vpn!(vpn.id)
    end

    test "delete_vpn/1 deletes the vpn" do
      vpn = vpn_fixture()
      assert {:ok, %Vpn{}} = Vpns.delete_vpn(vpn)
      assert_raise Ecto.NoResultsError, fn -> Vpns.get_vpn!(vpn.id) end
    end

    test "change_vpn/1 returns a vpn changeset" do
      vpn = vpn_fixture()
      assert %Ecto.Changeset{} = Vpns.change_vpn(vpn)
    end
  end
end
