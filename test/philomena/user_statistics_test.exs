defmodule Philomena.UserStatisticsTest do
  use Philomena.DataCase, async: true

  import Philomena.UsersFixtures

  alias Philomena.Multi
  alias Philomena.Repo
  alias Philomena.Users.User
  alias Philomena.UserStatistics
  alias Philomena.UserStatistics.UserStatistic

  test "increments a loaded user's lifetime and current UTC-day counters" do
    user = confirmed_user_fixture()

    assert UserStatistics.increment(user, :images_count) == {:ok, nil}

    assert Repo.get!(User, user.id).images_count == 1

    assert %UserStatistic{images_count: 1, day: day} =
             Repo.get_by!(UserStatistic, user_id: user.id)

    assert day == Date.utc_today()
  end

  test "accepts an ID and negative amounts" do
    user = confirmed_user_fixture()

    assert UserStatistics.increment(user.id, :comments_count, 4) == {:ok, nil}
    assert UserStatistics.increment(user.id, :comments_count, -2) == {:ok, nil}

    assert Repo.get!(User, user.id).comments_count == 2
    assert Repo.get_by!(UserStatistic, user_id: user.id).comments_count == 2
  end

  test "nil users are a no-op for anonymous activity" do
    assert UserStatistics.increment(nil, :comments_count) == {:ok, nil}
    assert Repo.aggregate(UserStatistic, :count) == 0
  end

  test "a missing user ID is not-found and creates no daily row" do
    assert UserStatistics.increment(2_000_000_000, :posts_count) == {:error, :not_found}
    assert Repo.aggregate(UserStatistic, :count) == 0
  end

  test "unknown keys and non-integer amounts do not match the service API" do
    user = confirmed_user_fixture()

    assert_raise FunctionClauseError, fn ->
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(UserStatistics, :increment, [user, :email, 1])
    end

    assert_raise FunctionClauseError, fn ->
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(UserStatistics, :increment, [user, :images_count, 1.5])
    end
  end

  test "an owning transaction rollback restores both counters" do
    user = confirmed_user_fixture()

    assert Repo.transact(fn ->
             assert UserStatistics.increment(user, :topics_count) == {:ok, nil}
             {:error, :forced_rollback}
           end) == {:error, :forced_rollback}

    assert Repo.get!(User, user.id).topics_count == 0
    refute Repo.get_by(UserStatistic, user_id: user.id)
  end

  test "bulk increments update each distinct user in an owning Multi" do
    first = confirmed_user_fixture()
    second = confirmed_user_fixture()

    assert {:ok, _changes} =
             Multi.new()
             |> UserStatistics.put_bulk_increment([first, second, first.id], :image_votes_count)
             |> Multi.transact()

    for user <- [first, second] do
      assert Repo.get!(User, user.id).image_votes_count == 1
      assert Repo.get_by!(UserStatistic, user_id: user.id).image_votes_count == 1
    end
  end

  test "bulk increments roll back with their owning Multi" do
    user = confirmed_user_fixture()

    assert {:error, :rollback, :forced_rollback, _changes} =
             Multi.new()
             |> UserStatistics.put_bulk_increment([user], :posts_count)
             |> Multi.run(:rollback, fn _repo, _changes -> {:error, :forced_rollback} end)
             |> Multi.transact()

    assert Repo.get!(User, user.id).posts_count == 0
    refute Repo.get_by(UserStatistic, user_id: user.id)
  end

  test "daily rows cascade on user deletion and deleted IDs are not-found" do
    user = confirmed_user_fixture()
    assert UserStatistics.increment(user, :posts_count) == {:ok, nil}

    Repo.delete!(user)

    refute Repo.get_by(UserStatistic, user_id: user.id)
    assert UserStatistics.increment(user.id, :posts_count) == {:error, :not_found}
  end
end
