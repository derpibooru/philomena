defmodule Philomena.UsersTest do
  use Philomena.DataCase

  alias Philomena.Users

  describe "user_ips" do
    alias Philomena.Users.Ip

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def ip_fixture(attrs \\ %{}) do
      {:ok, ip} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Users.create_ip()

      ip
    end

    test "list_user_ips/0 returns all user_ips" do
      ip = ip_fixture()
      assert Users.list_user_ips() == [ip]
    end

    test "get_ip!/1 returns the ip with given id" do
      ip = ip_fixture()
      assert Users.get_ip!(ip.id) == ip
    end

    test "create_ip/1 with valid data creates a ip" do
      assert {:ok, %Ip{} = ip} = Users.create_ip(@valid_attrs)
    end

    test "create_ip/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_ip(@invalid_attrs)
    end

    test "update_ip/2 with valid data updates the ip" do
      ip = ip_fixture()
      assert {:ok, %Ip{} = ip} = Users.update_ip(ip, @update_attrs)
    end

    test "update_ip/2 with invalid data returns error changeset" do
      ip = ip_fixture()
      assert {:error, %Ecto.Changeset{}} = Users.update_ip(ip, @invalid_attrs)
      assert ip == Users.get_ip!(ip.id)
    end

    test "delete_ip/1 deletes the ip" do
      ip = ip_fixture()
      assert {:ok, %Ip{}} = Users.delete_ip(ip)
      assert_raise Ecto.NoResultsError, fn -> Users.get_ip!(ip.id) end
    end

    test "change_ip/1 returns a ip changeset" do
      ip = ip_fixture()
      assert %Ecto.Changeset{} = Users.change_ip(ip)
    end
  end

  describe "user_fingerprints" do
    alias Philomena.Users.Fingerprints

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def fingerprints_fixture(attrs \\ %{}) do
      {:ok, fingerprints} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Users.create_fingerprints()

      fingerprints
    end

    test "list_user_fingerprints/0 returns all user_fingerprints" do
      fingerprints = fingerprints_fixture()
      assert Users.list_user_fingerprints() == [fingerprints]
    end

    test "get_fingerprints!/1 returns the fingerprints with given id" do
      fingerprints = fingerprints_fixture()
      assert Users.get_fingerprints!(fingerprints.id) == fingerprints
    end

    test "create_fingerprints/1 with valid data creates a fingerprints" do
      assert {:ok, %Fingerprints{} = fingerprints} = Users.create_fingerprints(@valid_attrs)
    end

    test "create_fingerprints/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_fingerprints(@invalid_attrs)
    end

    test "update_fingerprints/2 with valid data updates the fingerprints" do
      fingerprints = fingerprints_fixture()
      assert {:ok, %Fingerprints{} = fingerprints} = Users.update_fingerprints(fingerprints, @update_attrs)
    end

    test "update_fingerprints/2 with invalid data returns error changeset" do
      fingerprints = fingerprints_fixture()
      assert {:error, %Ecto.Changeset{}} = Users.update_fingerprints(fingerprints, @invalid_attrs)
      assert fingerprints == Users.get_fingerprints!(fingerprints.id)
    end

    test "delete_fingerprints/1 deletes the fingerprints" do
      fingerprints = fingerprints_fixture()
      assert {:ok, %Fingerprints{}} = Users.delete_fingerprints(fingerprints)
      assert_raise Ecto.NoResultsError, fn -> Users.get_fingerprints!(fingerprints.id) end
    end

    test "change_fingerprints/1 returns a fingerprints changeset" do
      fingerprints = fingerprints_fixture()
      assert %Ecto.Changeset{} = Users.change_fingerprints(fingerprints)
    end
  end
end
