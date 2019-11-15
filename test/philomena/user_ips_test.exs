defmodule Philomena.UserIpsTest do
  use Philomena.DataCase

  alias Philomena.UserIps

  describe "user_ips" do
    alias Philomena.UserIps.UserIp

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def user_ip_fixture(attrs \\ %{}) do
      {:ok, user_ip} =
        attrs
        |> Enum.into(@valid_attrs)
        |> UserIps.create_user_ip()

      user_ip
    end

    test "list_user_ips/0 returns all user_ips" do
      user_ip = user_ip_fixture()
      assert UserIps.list_user_ips() == [user_ip]
    end

    test "get_user_ip!/1 returns the user_ip with given id" do
      user_ip = user_ip_fixture()
      assert UserIps.get_user_ip!(user_ip.id) == user_ip
    end

    test "create_user_ip/1 with valid data creates a user_ip" do
      assert {:ok, %UserIp{} = user_ip} = UserIps.create_user_ip(@valid_attrs)
    end

    test "create_user_ip/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = UserIps.create_user_ip(@invalid_attrs)
    end

    test "update_user_ip/2 with valid data updates the user_ip" do
      user_ip = user_ip_fixture()
      assert {:ok, %UserIp{} = user_ip} = UserIps.update_user_ip(user_ip, @update_attrs)
    end

    test "update_user_ip/2 with invalid data returns error changeset" do
      user_ip = user_ip_fixture()
      assert {:error, %Ecto.Changeset{}} = UserIps.update_user_ip(user_ip, @invalid_attrs)
      assert user_ip == UserIps.get_user_ip!(user_ip.id)
    end

    test "delete_user_ip/1 deletes the user_ip" do
      user_ip = user_ip_fixture()
      assert {:ok, %UserIp{}} = UserIps.delete_user_ip(user_ip)
      assert_raise Ecto.NoResultsError, fn -> UserIps.get_user_ip!(user_ip.id) end
    end

    test "change_user_ip/1 returns a user_ip changeset" do
      user_ip = user_ip_fixture()
      assert %Ecto.Changeset{} = UserIps.change_user_ip(user_ip)
    end
  end
end
