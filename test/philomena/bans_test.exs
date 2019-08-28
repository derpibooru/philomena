defmodule Philomena.BansTest do
  use Philomena.DataCase

  alias Philomena.Bans

  describe "fingerprint_bans" do
    alias Philomena.Bans.Fingerprint

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def fingerprint_fixture(attrs \\ %{}) do
      {:ok, fingerprint} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Bans.create_fingerprint()

      fingerprint
    end

    test "list_fingerprint_bans/0 returns all fingerprint_bans" do
      fingerprint = fingerprint_fixture()
      assert Bans.list_fingerprint_bans() == [fingerprint]
    end

    test "get_fingerprint!/1 returns the fingerprint with given id" do
      fingerprint = fingerprint_fixture()
      assert Bans.get_fingerprint!(fingerprint.id) == fingerprint
    end

    test "create_fingerprint/1 with valid data creates a fingerprint" do
      assert {:ok, %Fingerprint{} = fingerprint} = Bans.create_fingerprint(@valid_attrs)
    end

    test "create_fingerprint/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Bans.create_fingerprint(@invalid_attrs)
    end

    test "update_fingerprint/2 with valid data updates the fingerprint" do
      fingerprint = fingerprint_fixture()
      assert {:ok, %Fingerprint{} = fingerprint} = Bans.update_fingerprint(fingerprint, @update_attrs)
    end

    test "update_fingerprint/2 with invalid data returns error changeset" do
      fingerprint = fingerprint_fixture()
      assert {:error, %Ecto.Changeset{}} = Bans.update_fingerprint(fingerprint, @invalid_attrs)
      assert fingerprint == Bans.get_fingerprint!(fingerprint.id)
    end

    test "delete_fingerprint/1 deletes the fingerprint" do
      fingerprint = fingerprint_fixture()
      assert {:ok, %Fingerprint{}} = Bans.delete_fingerprint(fingerprint)
      assert_raise Ecto.NoResultsError, fn -> Bans.get_fingerprint!(fingerprint.id) end
    end

    test "change_fingerprint/1 returns a fingerprint changeset" do
      fingerprint = fingerprint_fixture()
      assert %Ecto.Changeset{} = Bans.change_fingerprint(fingerprint)
    end
  end

  describe "subnet_bans" do
    alias Philomena.Bans.Subnet

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def subnet_fixture(attrs \\ %{}) do
      {:ok, subnet} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Bans.create_subnet()

      subnet
    end

    test "list_subnet_bans/0 returns all subnet_bans" do
      subnet = subnet_fixture()
      assert Bans.list_subnet_bans() == [subnet]
    end

    test "get_subnet!/1 returns the subnet with given id" do
      subnet = subnet_fixture()
      assert Bans.get_subnet!(subnet.id) == subnet
    end

    test "create_subnet/1 with valid data creates a subnet" do
      assert {:ok, %Subnet{} = subnet} = Bans.create_subnet(@valid_attrs)
    end

    test "create_subnet/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Bans.create_subnet(@invalid_attrs)
    end

    test "update_subnet/2 with valid data updates the subnet" do
      subnet = subnet_fixture()
      assert {:ok, %Subnet{} = subnet} = Bans.update_subnet(subnet, @update_attrs)
    end

    test "update_subnet/2 with invalid data returns error changeset" do
      subnet = subnet_fixture()
      assert {:error, %Ecto.Changeset{}} = Bans.update_subnet(subnet, @invalid_attrs)
      assert subnet == Bans.get_subnet!(subnet.id)
    end

    test "delete_subnet/1 deletes the subnet" do
      subnet = subnet_fixture()
      assert {:ok, %Subnet{}} = Bans.delete_subnet(subnet)
      assert_raise Ecto.NoResultsError, fn -> Bans.get_subnet!(subnet.id) end
    end

    test "change_subnet/1 returns a subnet changeset" do
      subnet = subnet_fixture()
      assert %Ecto.Changeset{} = Bans.change_subnet(subnet)
    end
  end

  describe "user_bans" do
    alias Philomena.Bans.User

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def user_fixture(attrs \\ %{}) do
      {:ok, user} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Bans.create_user()

      user
    end

    test "list_user_bans/0 returns all user_bans" do
      user = user_fixture()
      assert Bans.list_user_bans() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Bans.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      assert {:ok, %User{} = user} = Bans.create_user(@valid_attrs)
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Bans.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      assert {:ok, %User{} = user} = Bans.update_user(user, @update_attrs)
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Bans.update_user(user, @invalid_attrs)
      assert user == Bans.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Bans.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Bans.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Bans.change_user(user)
    end
  end
end
