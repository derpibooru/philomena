defmodule Philomena.BadgesTest do
  use Philomena.DataCase

  alias Philomena.Badges

  describe "badges" do
    alias Philomena.Badges.Badge

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def badge_fixture(attrs \\ %{}) do
      {:ok, badge} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Badges.create_badge()

      badge
    end

    test "list_badges/0 returns all badges" do
      badge = badge_fixture()
      assert Badges.list_badges() == [badge]
    end

    test "get_badge!/1 returns the badge with given id" do
      badge = badge_fixture()
      assert Badges.get_badge!(badge.id) == badge
    end

    test "create_badge/1 with valid data creates a badge" do
      assert {:ok, %Badge{} = badge} = Badges.create_badge(@valid_attrs)
    end

    test "create_badge/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Badges.create_badge(@invalid_attrs)
    end

    test "update_badge/2 with valid data updates the badge" do
      badge = badge_fixture()
      assert {:ok, %Badge{} = badge} = Badges.update_badge(badge, @update_attrs)
    end

    test "update_badge/2 with invalid data returns error changeset" do
      badge = badge_fixture()
      assert {:error, %Ecto.Changeset{}} = Badges.update_badge(badge, @invalid_attrs)
      assert badge == Badges.get_badge!(badge.id)
    end

    test "delete_badge/1 deletes the badge" do
      badge = badge_fixture()
      assert {:ok, %Badge{}} = Badges.delete_badge(badge)
      assert_raise Ecto.NoResultsError, fn -> Badges.get_badge!(badge.id) end
    end

    test "change_badge/1 returns a badge changeset" do
      badge = badge_fixture()
      assert %Ecto.Changeset{} = Badges.change_badge(badge)
    end
  end

  describe "badge_awards" do
    alias Philomena.Badges.BadgeAward

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def badge_award_fixture(attrs \\ %{}) do
      {:ok, badge_award} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Badges.create_badge_award()

      badge_award
    end

    test "list_badge_awards/0 returns all badge_awards" do
      badge_award = badge_award_fixture()
      assert Badges.list_badge_awards() == [badge_award]
    end

    test "get_badge_award!/1 returns the badge_award with given id" do
      badge_award = badge_award_fixture()
      assert Badges.get_badge_award!(badge_award.id) == badge_award
    end

    test "create_badge_award/1 with valid data creates a badge_award" do
      assert {:ok, %BadgeAward{} = badge_award} = Badges.create_badge_award(@valid_attrs)
    end

    test "create_badge_award/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Badges.create_badge_award(@invalid_attrs)
    end

    test "update_badge_award/2 with valid data updates the badge_award" do
      badge_award = badge_award_fixture()

      assert {:ok, %BadgeAward{} = badge_award} =
               Badges.update_badge_award(badge_award, @update_attrs)
    end

    test "update_badge_award/2 with invalid data returns error changeset" do
      badge_award = badge_award_fixture()
      assert {:error, %Ecto.Changeset{}} = Badges.update_badge_award(badge_award, @invalid_attrs)
      assert badge_award == Badges.get_badge_award!(badge_award.id)
    end

    test "delete_badge_award/1 deletes the badge_award" do
      badge_award = badge_award_fixture()
      assert {:ok, %BadgeAward{}} = Badges.delete_badge_award(badge_award)
      assert_raise Ecto.NoResultsError, fn -> Badges.get_badge_award!(badge_award.id) end
    end

    test "change_badge_award/1 returns a badge_award changeset" do
      badge_award = badge_award_fixture()
      assert %Ecto.Changeset{} = Badges.change_badge_award(badge_award)
    end
  end
end
