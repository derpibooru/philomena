defmodule Philomena.ForumsTest do
  @moduledoc """
  Context tests for actor-visible forum discovery, subscription toggles, and
  staff management. They cover malformed/missing/forbidden result precedence,
  write-access parity, idempotent subscription changes, and actor-specific
  forum/topic counts.
  """

  use Philomena.DataCase, async: true

  import Ecto.Query

  import Philomena.AttributionFixtures
  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo
  alias Philomena.Forums
  alias Philomena.Forums.Forum
  alias Philomena.Forums.ForumIndex
  alias Philomena.Forums.Subscription

  @pagination %{page_number: 1, page_size: 25}

  defp subscribed?(forum, user) do
    Repo.exists?(
      from s in Subscription,
        where: s.forum_id == ^forum.id and s.user_id == ^user.id
    )
  end

  defp subscription_count(forum, user) do
    Repo.aggregate(
      from(s in Subscription, where: s.forum_id == ^forum.id and s.user_id == ^user.id),
      :count
    )
  end

  describe "list_forums/1" do
    test "forum and topic counts include hidden topics but not inaccessible forums" do
      user = confirmed_user_fixture()
      moderator = moderator_user_fixture()
      public_forum = forum_fixture()
      restricted_forum = forum_fixture(access_level: "staff")
      _visible_topic = topic_fixture(public_forum)
      hidden_topic = topic_fixture(public_forum)
      _restricted_topic = topic_fixture(restricted_forum)

      {:ok, {_forum, _hidden_topic}} =
        Philomena.Topics.create_topic_hide(
          Philomena.AttributionFixtures.actor(moderator),
          public_forum.short_name,
          hidden_topic.slug,
          %{"deletion_reason" => "Spam"}
        )

      assert %ForumIndex{forums: user_forums, topic_count: 1} =
               Forums.list_forums(actor(user), @pagination)

      assert Enum.map(user_forums, & &1.id) == [public_forum.id]

      assert %ForumIndex{forums: moderator_forums, topic_count: 2} =
               Forums.list_forums(actor(moderator), @pagination)

      assert Enum.sort(Enum.map(moderator_forums, & &1.id)) ==
               Enum.sort([public_forum.id, restricted_forum.id])
    end
  end

  describe "create_forum_subscription/2" do
    test "a regular user subscribes to a visible forum and the row is created" do
      user = confirmed_user_fixture()
      forum = forum_fixture()

      assert {:ok, loaded_forum} = Forums.create_forum_subscription(actor(user), forum.short_name)

      assert loaded_forum.id == forum.id
      assert subscribed?(forum, user)
    end

    test "subscribing twice is idempotent and leaves a single row" do
      # create_subscription inserts with on_conflict: :nothing, so a repeat is a
      # successful no-op rather than a changeset error.
      user = confirmed_user_fixture()
      forum = forum_fixture()

      assert {:ok, _} = Forums.create_forum_subscription(actor(user), forum.short_name)
      assert {:ok, _} = Forums.create_forum_subscription(actor(user), forum.short_name)

      assert subscription_count(forum, user) == 1
    end

    test "a moderator subscribes to a visible forum" do
      moderator = moderator_user_fixture()
      forum = forum_fixture()

      assert {:ok, loaded_forum} =
               Forums.create_forum_subscription(actor(moderator), forum.short_name)

      assert loaded_forum.id == forum.id
      assert subscribed?(forum, moderator)
    end

    test "an admin subscribes to a visible forum" do
      admin = admin_user_fixture()
      forum = forum_fixture()

      assert {:ok, _forum} = Forums.create_forum_subscription(actor(admin), forum.short_name)
      assert subscribed?(forum, admin)
    end

    test "an unknown forum slug is not found for a regular user" do
      assert Forums.create_forum_subscription(actor(confirmed_user_fixture()), "nonexistent") ==
               {:error, :not_found}
    end

    test "an unknown forum slug is not found for anonymous" do
      assert Forums.create_forum_subscription(actor(), "nonexistent") == {:error, :not_found}
    end

    test "a restricted forum is unauthorized for a regular user and no row is created" do
      user = confirmed_user_fixture()
      forum = forum_fixture(access_level: "staff")

      assert Forums.create_forum_subscription(actor(user), forum.short_name) ==
               {:error, :unauthorized}

      refute subscribed?(forum, user)
    end

    test "a restricted forum is subscribable by a moderator" do
      moderator = moderator_user_fixture()
      forum = forum_fixture(access_level: "staff")

      assert {:ok, _forum} = Forums.create_forum_subscription(actor(moderator), forum.short_name)
      assert subscribed?(forum, moderator)
    end

    test "anonymous cannot create_forum_subscription to a visible forum" do
      forum = forum_fixture()

      assert Forums.create_forum_subscription(actor(), forum.short_name) ==
               {:error, :unauthorized}
    end

    test "an admin with an unknown forum gets not-found" do
      assert Forums.create_forum_subscription(actor(admin_user_fixture()), "nonexistent") ==
               {:error, :not_found}
    end
  end

  describe "delete_forum_subscription/2" do
    test "a regular user unsubscribes from a visible forum and the row is removed" do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      {:ok, _} = Forums.create_subscription(forum, user)
      assert subscribed?(forum, user)

      assert {:ok, loaded_forum} = Forums.delete_forum_subscription(actor(user), forum.short_name)

      assert loaded_forum.id == forum.id
      refute subscribed?(forum, user)
    end

    test "unsubscribing with no existing subscription still succeeds" do
      # delete_subscription runs an unconditional delete_all and hard-matches
      # {:ok, _}, so the absence of a row is not an error.
      user = confirmed_user_fixture()
      forum = forum_fixture()
      refute subscribed?(forum, user)

      assert {:ok, _forum} = Forums.delete_forum_subscription(actor(user), forum.short_name)
      refute subscribed?(forum, user)
    end

    test "a moderator unsubscribes from a visible forum" do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      {:ok, _} = Forums.create_subscription(forum, moderator)

      assert {:ok, _forum} = Forums.delete_forum_subscription(actor(moderator), forum.short_name)
      refute subscribed?(forum, moderator)
    end

    test "an unknown forum slug is not found for a regular user" do
      assert Forums.delete_forum_subscription(actor(confirmed_user_fixture()), "nonexistent") ==
               {:error, :not_found}
    end

    test "a restricted forum is unauthorized for a regular user" do
      user = confirmed_user_fixture()
      forum = forum_fixture(access_level: "staff")

      assert Forums.delete_forum_subscription(actor(user), forum.short_name) ==
               {:error, :unauthorized}
    end
  end

  describe "list_admin_forums/1" do
    test "an admin receives the forum list" do
      forum = forum_fixture()
      assert {:ok, forums} = Forums.list_admin_forums(actor(admin_user_fixture()))
      assert Enum.any?(forums, &(&1.id == forum.id))
    end

    test "a plain moderator is not authorized" do
      assert Forums.list_admin_forums(actor(moderator_user_fixture())) == {:error, :unauthorized}
    end

    test "a regular user is not authorized" do
      assert Forums.list_admin_forums(actor(confirmed_user_fixture())) == {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      assert Forums.list_admin_forums(actor()) == {:error, :unauthorized}
    end
  end

  describe "new_forum/1" do
    test "an admin gets a changeset" do
      assert {:ok, %Ecto.Changeset{}} = Forums.new_forum(actor(admin_user_fixture()))
    end

    test "a plain moderator is not authorized" do
      assert Forums.new_forum(actor(moderator_user_fixture())) == {:error, :unauthorized}
    end

    test "a regular user is not authorized" do
      assert Forums.new_forum(actor(confirmed_user_fixture())) == {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      assert Forums.new_forum(actor()) == {:error, :unauthorized}
    end
  end

  describe "create_forum/2" do
    test "an admin creates a forum" do
      assert {:ok, %Forum{} = forum} =
               Forums.create_forum(actor(admin_user_fixture()), valid_attrs())

      assert Repo.get(Forum, forum.id)
    end

    test "invalid attributes return a changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Forums.create_forum(actor(admin_user_fixture()), %{valid_attrs() | "name" => ""})
    end

    test "a plain moderator is not authorized and creates nothing" do
      assert Forums.create_forum(actor(moderator_user_fixture()), valid_attrs()) ==
               {:error, :unauthorized}
    end

    test "a regular user is not authorized" do
      assert Forums.create_forum(actor(confirmed_user_fixture()), valid_attrs()) ==
               {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      assert Forums.create_forum(actor(), valid_attrs()) == {:error, :unauthorized}
    end
  end

  describe "edit_forum/2" do
    test "an admin loads a forum by short name" do
      forum = forum_fixture()

      assert {:ok, {loaded, %Ecto.Changeset{}}} =
               Forums.edit_forum(actor(admin_user_fixture()), forum.short_name)

      assert loaded.id == forum.id
    end

    test "an unknown short name is not found for an admin" do
      assert Forums.edit_forum(actor(admin_user_fixture()), "nonexistent") ==
               {:error, :not_found}
    end

    test "an unknown short name is not found for a plain moderator" do
      assert Forums.edit_forum(actor(moderator_user_fixture()), "nonexistent") ==
               {:error, :not_found}
    end

    test "a real forum is unauthorized for a plain moderator" do
      forum = forum_fixture()

      assert Forums.edit_forum(actor(moderator_user_fixture()), forum.short_name) ==
               {:error, :unauthorized}
    end

    test "a regular user is not authorized" do
      forum = forum_fixture()

      assert Forums.edit_forum(actor(confirmed_user_fixture()), forum.short_name) ==
               {:error, :unauthorized}
    end
  end

  describe "update_forum/3" do
    test "an admin updates a forum" do
      forum = forum_fixture()

      assert {:ok, updated} =
               Forums.update_forum(actor(admin_user_fixture()), forum.short_name, %{
                 "name" => "Renamed"
               })

      assert updated.name == "Renamed"
    end

    test "invalid attributes return a changeset" do
      forum = forum_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Forums.update_forum(actor(admin_user_fixture()), forum.short_name, %{"name" => ""})
    end

    test "an unknown short name is not found for an admin" do
      assert Forums.update_forum(actor(admin_user_fixture()), "nonexistent", %{"name" => "x"}) ==
               {:error, :not_found}
    end

    test "an unknown short name is not found for a plain moderator" do
      assert Forums.update_forum(actor(moderator_user_fixture()), "nonexistent", %{"name" => "x"}) ==
               {:error, :not_found}
    end

    test "a real forum is unauthorized for a plain moderator" do
      forum = forum_fixture()

      assert Forums.update_forum(actor(moderator_user_fixture()), forum.short_name, %{
               "name" => "x"
             }) ==
               {:error, :unauthorized}
    end

    test "a regular user is not authorized" do
      forum = forum_fixture()

      assert Forums.update_forum(actor(confirmed_user_fixture()), forum.short_name, %{
               "name" => "x"
             }) ==
               {:error, :unauthorized}
    end
  end

  # Controller-shaped attrs (string keys) a forum insert requires; the short
  # name must be lowercase letters only.
  defp valid_attrs do
    %{
      "name" => "Admin Test Forum",
      "short_name" => unique_forum_short_name(),
      "description" => "A forum created in an admin test",
      "access_level" => "normal"
    }
  end
end
