defmodule Philomena.UserStatisticsTest do
  use Philomena.DataCase

  alias Philomena.UserStatistics

  describe "user_statistics" do
    alias Philomena.UserStatistics.UserStatistic

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def user_statistic_fixture(attrs \\ %{}) do
      {:ok, user_statistic} =
        attrs
        |> Enum.into(@valid_attrs)
        |> UserStatistics.create_user_statistic()

      user_statistic
    end

    test "list_user_statistics/0 returns all user_statistics" do
      user_statistic = user_statistic_fixture()
      assert UserStatistics.list_user_statistics() == [user_statistic]
    end

    test "get_user_statistic!/1 returns the user_statistic with given id" do
      user_statistic = user_statistic_fixture()
      assert UserStatistics.get_user_statistic!(user_statistic.id) == user_statistic
    end

    test "create_user_statistic/1 with valid data creates a user_statistic" do
      assert {:ok, %UserStatistic{} = user_statistic} = UserStatistics.create_user_statistic(@valid_attrs)
    end

    test "create_user_statistic/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = UserStatistics.create_user_statistic(@invalid_attrs)
    end

    test "update_user_statistic/2 with valid data updates the user_statistic" do
      user_statistic = user_statistic_fixture()
      assert {:ok, %UserStatistic{} = user_statistic} = UserStatistics.update_user_statistic(user_statistic, @update_attrs)
    end

    test "update_user_statistic/2 with invalid data returns error changeset" do
      user_statistic = user_statistic_fixture()
      assert {:error, %Ecto.Changeset{}} = UserStatistics.update_user_statistic(user_statistic, @invalid_attrs)
      assert user_statistic == UserStatistics.get_user_statistic!(user_statistic.id)
    end

    test "delete_user_statistic/1 deletes the user_statistic" do
      user_statistic = user_statistic_fixture()
      assert {:ok, %UserStatistic{}} = UserStatistics.delete_user_statistic(user_statistic)
      assert_raise Ecto.NoResultsError, fn -> UserStatistics.get_user_statistic!(user_statistic.id) end
    end

    test "change_user_statistic/1 returns a user_statistic changeset" do
      user_statistic = user_statistic_fixture()
      assert %Ecto.Changeset{} = UserStatistics.change_user_statistic(user_statistic)
    end
  end
end
