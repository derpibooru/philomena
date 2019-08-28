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

  describe "user_links" do
    alias Philomena.Users.Link

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def link_fixture(attrs \\ %{}) do
      {:ok, link} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Users.create_link()

      link
    end

    test "list_user_links/0 returns all user_links" do
      link = link_fixture()
      assert Users.list_user_links() == [link]
    end

    test "get_link!/1 returns the link with given id" do
      link = link_fixture()
      assert Users.get_link!(link.id) == link
    end

    test "create_link/1 with valid data creates a link" do
      assert {:ok, %Link{} = link} = Users.create_link(@valid_attrs)
    end

    test "create_link/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_link(@invalid_attrs)
    end

    test "update_link/2 with valid data updates the link" do
      link = link_fixture()
      assert {:ok, %Link{} = link} = Users.update_link(link, @update_attrs)
    end

    test "update_link/2 with invalid data returns error changeset" do
      link = link_fixture()
      assert {:error, %Ecto.Changeset{}} = Users.update_link(link, @invalid_attrs)
      assert link == Users.get_link!(link.id)
    end

    test "delete_link/1 deletes the link" do
      link = link_fixture()
      assert {:ok, %Link{}} = Users.delete_link(link)
      assert_raise Ecto.NoResultsError, fn -> Users.get_link!(link.id) end
    end

    test "change_link/1 returns a link changeset" do
      link = link_fixture()
      assert %Ecto.Changeset{} = Users.change_link(link)
    end
  end

  describe "user_name_changes" do
    alias Philomena.Users.NameChange

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def name_change_fixture(attrs \\ %{}) do
      {:ok, name_change} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Users.create_name_change()

      name_change
    end

    test "list_user_name_changes/0 returns all user_name_changes" do
      name_change = name_change_fixture()
      assert Users.list_user_name_changes() == [name_change]
    end

    test "get_name_change!/1 returns the name_change with given id" do
      name_change = name_change_fixture()
      assert Users.get_name_change!(name_change.id) == name_change
    end

    test "create_name_change/1 with valid data creates a name_change" do
      assert {:ok, %NameChange{} = name_change} = Users.create_name_change(@valid_attrs)
    end

    test "create_name_change/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_name_change(@invalid_attrs)
    end

    test "update_name_change/2 with valid data updates the name_change" do
      name_change = name_change_fixture()
      assert {:ok, %NameChange{} = name_change} = Users.update_name_change(name_change, @update_attrs)
    end

    test "update_name_change/2 with invalid data returns error changeset" do
      name_change = name_change_fixture()
      assert {:error, %Ecto.Changeset{}} = Users.update_name_change(name_change, @invalid_attrs)
      assert name_change == Users.get_name_change!(name_change.id)
    end

    test "delete_name_change/1 deletes the name_change" do
      name_change = name_change_fixture()
      assert {:ok, %NameChange{}} = Users.delete_name_change(name_change)
      assert_raise Ecto.NoResultsError, fn -> Users.get_name_change!(name_change.id) end
    end

    test "change_name_change/1 returns a name_change changeset" do
      name_change = name_change_fixture()
      assert %Ecto.Changeset{} = Users.change_name_change(name_change)
    end
  end

  describe "user_statistics" do
    alias Philomena.Users.Statistic

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def statistic_fixture(attrs \\ %{}) do
      {:ok, statistic} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Users.create_statistic()

      statistic
    end

    test "list_user_statistics/0 returns all user_statistics" do
      statistic = statistic_fixture()
      assert Users.list_user_statistics() == [statistic]
    end

    test "get_statistic!/1 returns the statistic with given id" do
      statistic = statistic_fixture()
      assert Users.get_statistic!(statistic.id) == statistic
    end

    test "create_statistic/1 with valid data creates a statistic" do
      assert {:ok, %Statistic{} = statistic} = Users.create_statistic(@valid_attrs)
    end

    test "create_statistic/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_statistic(@invalid_attrs)
    end

    test "update_statistic/2 with valid data updates the statistic" do
      statistic = statistic_fixture()
      assert {:ok, %Statistic{} = statistic} = Users.update_statistic(statistic, @update_attrs)
    end

    test "update_statistic/2 with invalid data returns error changeset" do
      statistic = statistic_fixture()
      assert {:error, %Ecto.Changeset{}} = Users.update_statistic(statistic, @invalid_attrs)
      assert statistic == Users.get_statistic!(statistic.id)
    end

    test "delete_statistic/1 deletes the statistic" do
      statistic = statistic_fixture()
      assert {:ok, %Statistic{}} = Users.delete_statistic(statistic)
      assert_raise Ecto.NoResultsError, fn -> Users.get_statistic!(statistic.id) end
    end

    test "change_statistic/1 returns a statistic changeset" do
      statistic = statistic_fixture()
      assert %Ecto.Changeset{} = Users.change_statistic(statistic)
    end
  end

  describe "user_whitelists" do
    alias Philomena.Users.Whitelist

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def whitelist_fixture(attrs \\ %{}) do
      {:ok, whitelist} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Users.create_whitelist()

      whitelist
    end

    test "list_user_whitelists/0 returns all user_whitelists" do
      whitelist = whitelist_fixture()
      assert Users.list_user_whitelists() == [whitelist]
    end

    test "get_whitelist!/1 returns the whitelist with given id" do
      whitelist = whitelist_fixture()
      assert Users.get_whitelist!(whitelist.id) == whitelist
    end

    test "create_whitelist/1 with valid data creates a whitelist" do
      assert {:ok, %Whitelist{} = whitelist} = Users.create_whitelist(@valid_attrs)
    end

    test "create_whitelist/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_whitelist(@invalid_attrs)
    end

    test "update_whitelist/2 with valid data updates the whitelist" do
      whitelist = whitelist_fixture()
      assert {:ok, %Whitelist{} = whitelist} = Users.update_whitelist(whitelist, @update_attrs)
    end

    test "update_whitelist/2 with invalid data returns error changeset" do
      whitelist = whitelist_fixture()
      assert {:error, %Ecto.Changeset{}} = Users.update_whitelist(whitelist, @invalid_attrs)
      assert whitelist == Users.get_whitelist!(whitelist.id)
    end

    test "delete_whitelist/1 deletes the whitelist" do
      whitelist = whitelist_fixture()
      assert {:ok, %Whitelist{}} = Users.delete_whitelist(whitelist)
      assert_raise Ecto.NoResultsError, fn -> Users.get_whitelist!(whitelist.id) end
    end

    test "change_whitelist/1 returns a whitelist changeset" do
      whitelist = whitelist_fixture()
      assert %Ecto.Changeset{} = Users.change_whitelist(whitelist)
    end
  end
end
