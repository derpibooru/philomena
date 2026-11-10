defmodule Philomena.TopicsTest do
  @moduledoc """
  Context-level tests for the actor-first topic APIs on `Philomena.Topics`:
  `subscribe/3`, `unsubscribe/3`, and `mark_topic_read/3`.

  These pin the authorization matrix (anonymous / user / moderator / admin),
  the failure divergence between the two actions (unknown forum, unknown topic,
  hidden topic), and the idempotent success paths. The corresponding controller
  characterization tests pin the HTTP behavior on top of these results.

  The actor here is a `Philomena.Attribution.Actor`, matching what the controller
  hands in as `conn.assigns.actor`.
  """

  use Philomena.DataCase, async: true

  import Ecto.Query

  import Philomena.AttributionFixtures
  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.RulesFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Forums.Forum
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Notifications
  alias Philomena.Notifications.ForumPostNotification
  alias Philomena.Posts
  alias Philomena.Posts.Post
  alias Philomena.Reports.Report
  alias Philomena.Repo
  alias Philomena.Topics
  alias Philomena.Topics.Subscription
  alias Philomena.Topics.Topic
  alias Philomena.Topics.TopicPage
  alias Philomena.Users.User

  # A truthy ban value in the shape production passes (the result of
  # Philomena.Bans.find/3); only its presence matters to verify_write_access
  # and the global write prerequisite.
  @ban %{
    reason: "Rule #0",
    valid_until: ~U[3000-01-01 00:00:00Z],
    generated_ban_id: "U123456",
    type: "User"
  }

  # The request pagination map show_topic_page reads.
  @first_page %{page_number: 1, page_size: 25}

  defp subscribed?(topic, user) do
    Repo.exists?(
      from s in Subscription,
        where: s.topic_id == ^topic.id and s.user_id == ^user.id
    )
  end

  defp post_notification?(topic, user) do
    Repo.exists?(
      from n in ForumPostNotification,
        where: n.topic_id == ^topic.id and n.user_id == ^user.id
    )
  end

  defp subscription_count(topic, user) do
    Repo.aggregate(
      from(s in Subscription, where: s.topic_id == ^topic.id and s.user_id == ^user.id),
      :count
    )
  end

  # A visible topic in a normal (publicly readable) forum, the common case both
  # actions load through.
  defp visible_topic do
    forum = forum_fixture()
    topic = topic_fixture(forum)
    {forum, topic}
  end

  # A hidden topic in a normal forum, the shape delete_topic_hide/3 operates on.
  defp hidden_topic do
    forum = forum_fixture()
    topic = topic_fixture(forum)
    moderator = moderator_user_fixture()

    {:ok, {_forum, hidden}} =
      Topics.create_topic_hide(actor(moderator), forum.short_name, topic.slug, %{
        "deletion_reason" => "Spam"
      })

    {forum, hidden}
  end

  # A locked topic in a normal forum, the shape delete_topic_lock/3 operates on.
  # Locking (unlike hiding) leaves the topic visible, so the loader still admits
  # a regular user.
  defp locked_topic do
    forum = forum_fixture()
    topic = topic_fixture(forum)

    moderator = moderator_user_fixture()

    {:ok, {_forum, locked}} =
      Topics.create_topic_lock(actor(moderator), forum.short_name, topic.slug, %{
        "lock_reason" => "Off topic"
      })

    {forum, locked}
  end

  # A sticky topic in a normal forum, the shape delete_topic_stick/3 operates on.
  # Sticking (like locking) leaves the topic visible, so the loader still admits
  # a regular user.
  defp sticky_topic do
    forum = forum_fixture()
    topic = topic_fixture(forum)
    moderator = moderator_user_fixture()

    {:ok, {_forum, sticky}} =
      Topics.create_topic_stick(actor(moderator), forum.short_name, topic.slug)

    {forum, sticky}
  end

  defp latest_moderation_log! do
    Repo.one!(from log in ModerationLog, order_by: [desc: log.id], limit: 1)
  end

  defp moderation_log_count, do: Repo.aggregate(ModerationLog, :count)

  describe "create_topic_subscription/3" do
    test "a regular user subscribes to a visible topic and the row is created" do
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()

      assert {:ok, {loaded_forum, loaded_topic}} =
               Topics.create_topic_subscription(actor(user), forum.short_name, topic.slug)

      assert loaded_forum.id == forum.id
      assert loaded_topic.id == topic.id
      assert subscribed?(topic, user)
    end

    test "subscribing twice is idempotent and leaves a single row" do
      # create_subscription inserts with on_conflict: :nothing, so a repeat is a
      # successful no-op rather than a changeset error.
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()

      assert {:ok, _} =
               Topics.create_topic_subscription(actor(user), forum.short_name, topic.slug)

      assert {:ok, _} =
               Topics.create_topic_subscription(actor(user), forum.short_name, topic.slug)

      assert subscription_count(topic, user) == 1
    end

    test "a moderator subscribes to a visible topic" do
      moderator = moderator_user_fixture()
      {forum, topic} = visible_topic()

      assert {:ok, {_forum, _topic}} =
               Topics.create_topic_subscription(actor(moderator), forum.short_name, topic.slug)

      assert subscribed?(topic, moderator)
    end

    test "an admin subscribes to a visible topic" do
      admin = admin_user_fixture()
      {forum, topic} = visible_topic()

      assert {:ok, {_forum, _topic}} =
               Topics.create_topic_subscription(actor(admin), forum.short_name, topic.slug)

      assert subscribed?(topic, admin)
    end

    test "an unknown forum slug is unauthorized for a regular user" do
      # An unknown short name loads nil, and authorizing nil for :show is
      # unauthorized for every non-admin actor.
      assert Topics.create_topic_subscription(
               actor(confirmed_user_fixture()),
               "nonexistent",
               "whatever"
             ) ==
               {:error, :not_found}
    end

    test "an unknown forum slug is unauthorized for anonymous" do
      assert Topics.create_topic_subscription(actor(), "nonexistent", "whatever") ==
               {:error, :not_found}
    end

    test "an existing forum with an unknown topic slug is not found" do
      forum = forum_fixture()

      assert Topics.create_topic_subscription(
               actor(confirmed_user_fixture()),
               forum.short_name,
               "nonexistent-topic"
             ) ==
               {:error, :not_found}
    end

    test "a restricted forum is unauthorized for a regular user" do
      user = confirmed_user_fixture()
      forum = forum_fixture(access_level: "staff")
      topic = topic_fixture(forum)

      assert Topics.create_topic_subscription(actor(user), forum.short_name, topic.slug) ==
               {:error, :unauthorized}

      refute subscribed?(topic, user)
    end

    test "a restricted forum is subscribable by a moderator" do
      moderator = moderator_user_fixture()
      forum = forum_fixture(access_level: "staff")
      topic = topic_fixture(forum)

      assert {:ok, {_forum, _topic}} =
               Topics.create_topic_subscription(actor(moderator), forum.short_name, topic.slug)

      assert subscribed?(topic, moderator)
    end

    test "a hidden topic is unauthorized for a regular user and no row is created" do
      # subscribe passes show_hidden: false, so a hidden topic falls to the
      # topic :show authorization, which a regular user fails.
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()
      moderator = moderator_user_fixture()

      {:ok, {_forum, topic}} =
        Topics.create_topic_hide(actor(moderator), forum.short_name, topic.slug, %{
          "deletion_reason" => "test hiding"
        })

      assert Topics.create_topic_subscription(actor(user), forum.short_name, topic.slug) ==
               {:error, :unauthorized}

      refute subscribed?(topic, user)
    end

    test "a hidden topic is subscribable by a moderator" do
      moderator = moderator_user_fixture()
      {forum, topic} = visible_topic()

      {:ok, {_forum, topic}} =
        Topics.create_topic_hide(actor(moderator), forum.short_name, topic.slug, %{
          "deletion_reason" => "test hiding"
        })

      assert {:ok, {_forum, _topic}} =
               Topics.create_topic_subscription(actor(moderator), forum.short_name, topic.slug)

      assert subscribed?(topic, moderator)
    end

    test "anonymous cannot create_topic_subscription to a visible topic" do
      {forum, topic} = visible_topic()

      assert Topics.create_topic_subscription(actor(), forum.short_name, topic.slug) ==
               {:error, :unauthorized}
    end

    test "an admin with an unknown forum gets not-found" do
      assert Topics.create_topic_subscription(
               actor(admin_user_fixture()),
               "nonexistent",
               "whatever"
             ) ==
               {:error, :not_found}
    end
  end

  describe "delete_topic_subscription/3" do
    test "a regular user unsubscribes from a visible topic and the row is removed" do
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()
      {:ok, _} = Topics.create_subscription(topic, user)
      assert subscribed?(topic, user)

      assert {:ok, {loaded_forum, loaded_topic}} =
               Topics.delete_topic_subscription(actor(user), forum.short_name, topic.slug)

      assert loaded_forum.id == forum.id
      assert loaded_topic.id == topic.id
      refute subscribed?(topic, user)
    end

    test "unsubscribing with no existing subscription still succeeds" do
      # delete_subscription runs an unconditional delete_all and hard-matches
      # {:ok, _}, so the absence of a row is not an error.
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()
      refute subscribed?(topic, user)

      assert {:ok, {_forum, _topic}} =
               Topics.delete_topic_subscription(actor(user), forum.short_name, topic.slug)

      refute subscribed?(topic, user)
    end

    test "a moderator unsubscribes from a visible topic" do
      moderator = moderator_user_fixture()
      {forum, topic} = visible_topic()
      {:ok, _} = Topics.create_subscription(topic, moderator)

      assert {:ok, {_forum, _topic}} =
               Topics.delete_topic_subscription(actor(moderator), forum.short_name, topic.slug)

      refute subscribed?(topic, moderator)
    end

    test "a hidden topic can still be unsubscribed from by a regular user" do
      # unsubscribe passes show_hidden: true, so a topic hidden after the user
      # subscribed stays reachable for removal.
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()
      {:ok, _} = Topics.create_subscription(topic, user)
      moderator = moderator_user_fixture()

      {:ok, {_forum, topic}} =
        Topics.create_topic_hide(actor(moderator), forum.short_name, topic.slug, %{
          "deletion_reason" => "test hiding"
        })

      assert {:ok, {_forum, _topic}} =
               Topics.delete_topic_subscription(actor(user), forum.short_name, topic.slug)

      refute subscribed?(topic, user)
    end

    test "an unknown forum slug is unauthorized for a regular user" do
      assert Topics.delete_topic_subscription(
               actor(confirmed_user_fixture()),
               "nonexistent",
               "whatever"
             ) ==
               {:error, :not_found}
    end

    test "an existing forum with an unknown topic slug is not found" do
      forum = forum_fixture()

      assert Topics.delete_topic_subscription(
               actor(confirmed_user_fixture()),
               forum.short_name,
               "nonexistent-topic"
             ) ==
               {:error, :not_found}
    end

    test "a restricted forum is unauthorized for a regular user" do
      user = confirmed_user_fixture()
      forum = forum_fixture(access_level: "staff")
      topic = topic_fixture(forum)

      assert Topics.delete_topic_subscription(actor(user), forum.short_name, topic.slug) ==
               {:error, :unauthorized}
    end
  end

  describe "create_topic_read/3" do
    test "an unknown forum slug is not found for a regular user" do
      # Divergence from create_topic_subscription/3: the read path loads the forum with a plain
      # required load and no authorization, so a missing forum is :not_found
      # rather than the :unauthorized that subscribe returns for a regular user.
      assert Topics.create_topic_read(actor(confirmed_user_fixture()), "nonexistent", "whatever") ==
               {:error, :not_found}
    end

    test "an unknown forum slug is not found for anonymous" do
      assert Topics.create_topic_read(actor(), "nonexistent", "whatever") == {:error, :not_found}
    end

    test "an existing forum with an unknown topic slug is not found" do
      forum = forum_fixture()

      assert Topics.create_topic_read(
               actor(confirmed_user_fixture()),
               forum.short_name,
               "nonexistent-topic"
             ) ==
               {:error, :not_found}
    end

    test "a hidden topic is marked read by a regular user with no visibility gate" do
      # The read path loads the topic with show_hidden: true and runs no :show
      # authorization, so a regular user reaches a hidden topic that create_topic_subscription/3
      # would refuse with :unauthorized.
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()
      moderator = moderator_user_fixture()

      {:ok, {_forum, topic}} =
        Topics.create_topic_hide(actor(moderator), forum.short_name, topic.slug, %{
          "deletion_reason" => "test hiding"
        })

      assert {:ok, loaded_topic} =
               Topics.create_topic_read(actor(user), forum.short_name, topic.slug)

      assert loaded_topic.id == topic.id
    end

    test "a staff-only forum cannot be marked read by a regular user" do
      user = confirmed_user_fixture()
      forum = forum_fixture(access_level: "staff")
      topic = topic_fixture(forum)

      assert Topics.create_topic_read(actor(user), forum.short_name, topic.slug) ==
               {:error, :unauthorized}
    end

    test "success clears the topic notification for the user" do
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()

      # Arrange a real unread notification the way the read controller test does:
      # subscribe the user to the topic, then have another user post so a
      # ForumPostNotification lands for the subscriber.
      {:ok, _} = Topics.create_subscription(topic, user)
      author = confirmed_user_fixture()
      post = hd(topic.posts)
      {:ok, 1} = Notifications.broadcast_forum_post(author, topic, post)
      assert post_notification?(topic, user)

      assert {:ok, _topic} = Topics.create_topic_read(actor(user), forum.short_name, topic.slug)
      refute post_notification?(topic, user)
    end

    test "marking read is safe when the user has no notifications" do
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()
      refute post_notification?(topic, user)

      assert {:ok, loaded_topic} =
               Topics.create_topic_read(actor(user), forum.short_name, topic.slug)

      assert loaded_topic.id == topic.id
    end

    test "an anonymous actor marks read harmlessly and returns the topic" do
      # clear_topic_notification/2 forwards nil to the notification clear
      # service, which returns {:ok, 0}, so an anonymous actor reaching
      # a visible topic is a successful no-op rather than a crash (contrast
      # create_topic_subscription/3, where the anonymous actor's nil user raises BadMapError in
      # create_subscription).
      {forum, topic} = visible_topic()

      assert {:ok, loaded_topic} = Topics.create_topic_read(actor(), forum.short_name, topic.slug)
      assert loaded_topic.id == topic.id
    end
  end

  describe "create_topic_hide/4" do
    test "a regular user cannot hide a visible topic and the topic stays visible" do
      # The visibility loader clears a regular user on a normal, visible topic;
      # the block on the topic :hide permission is what denies the action.
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()

      assert Topics.create_topic_hide(actor(user), forum.short_name, topic.slug, %{
               "deletion_reason" => "Spam"
             }) ==
               {:error, :unauthorized}

      refute Repo.reload!(topic).hidden_from_users
    end

    test "an anonymous actor cannot hide a visible topic" do
      # nil clears forum :show and topic visibility on normal content, but fails
      # the topic :hide permission, so this is a clean unauthorized rather than a
      # crash on the nil actor.
      {forum, topic} = visible_topic()

      assert Topics.create_topic_hide(actor(), forum.short_name, topic.slug, %{
               "deletion_reason" => "Spam"
             }) ==
               {:error, :unauthorized}

      refute Repo.reload!(topic).hidden_from_users
    end

    test "an unknown forum is unauthorized for a regular user" do
      assert Topics.create_topic_hide(
               actor(confirmed_user_fixture()),
               "nonexistent",
               "whatever",
               "Spam"
             ) ==
               {:error, :not_found}
    end

    test "an existing forum with an unknown topic is not found" do
      forum = forum_fixture()

      assert Topics.create_topic_hide(
               actor(moderator_user_fixture()),
               forum.short_name,
               "nonexistent-topic",
               %{"deletion_reason" => "Spam"}
             ) ==
               {:error, :not_found}
    end

    test "a moderator hides the topic, setting the flag, reason, and deleter" do
      moderator = moderator_user_fixture()
      {forum, topic} = visible_topic()

      assert {:ok, {loaded_forum, loaded_topic}} =
               Topics.create_topic_hide(actor(moderator), forum.short_name, topic.slug, %{
                 "deletion_reason" => "Rule violation"
               })

      assert loaded_forum.id == forum.id
      assert loaded_topic.id == topic.id

      hidden = Repo.reload!(topic)
      assert hidden.hidden_from_users
      assert hidden.deletion_reason == "Rule violation"
      assert hidden.deleted_by_id == moderator.id
    end

    test "a successful hide writes a byte-exact moderation log" do
      moderator = moderator_user_fixture()
      {forum, topic} = visible_topic()

      assert {:ok, _} =
               Topics.create_topic_hide(actor(moderator), forum.short_name, topic.slug, %{
                 "deletion_reason" => "Rule violation"
               })

      log = latest_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Topic.Hide:create"
      assert log.subject_path == "/forums/#{forum.short_name}/topics/#{topic.slug}"
      assert log.body == "Deleted topic '#{topic.title}' (Rule violation) in #{forum.name}"
    end

    test "a missing reason errors and writes no moderation log" do
      # hide_changeset requires deletion_reason; create_topic_hide/4 surfaces the
      # normalized changeset failure as {:error, forum, topic} (both the loaded
      # forum and the pre-update topic) so the controller can still redirect.
      moderator = moderator_user_fixture()

      {forum, topic} = visible_topic()

      assert {:error, blank_forum, blank_topic} =
               Topics.create_topic_hide(actor(moderator), forum.short_name, topic.slug, %{})

      assert blank_forum.id == forum.id
      assert blank_topic.id == topic.id

      {nil_forum, nil_topic} = visible_topic()

      assert {:error, error_forum, error_topic} =
               Topics.create_topic_hide(
                 actor(moderator),
                 nil_forum.short_name,
                 nil_topic.slug,
                 %{}
               )

      assert error_forum.id == nil_forum.id
      assert error_topic.id == nil_topic.id

      refute Repo.reload!(topic).hidden_from_users
      refute Repo.reload!(nil_topic).hidden_from_users
      assert moderation_log_count() == 0
    end
  end

  describe "delete_topic_hide/3" do
    test "a regular user cannot reach a hidden topic through the visibility loader" do
      # delete_topic_hide/3 loads with show_hidden: false, so a hidden topic falls to
      # the topic :show check, which a regular user fails before :hide is even
      # considered.
      user = confirmed_user_fixture()
      {forum, topic} = hidden_topic()

      assert Topics.delete_topic_hide(actor(user), forum.short_name, topic.slug) ==
               {:error, :unauthorized}

      assert Repo.reload!(topic).hidden_from_users
    end

    test "an anonymous actor cannot reach a hidden topic" do
      {forum, topic} = hidden_topic()

      assert Topics.delete_topic_hide(actor(), forum.short_name, topic.slug) ==
               {:error, :unauthorized}

      assert Repo.reload!(topic).hidden_from_users
    end

    test "an unknown forum is unauthorized for a regular user" do
      assert Topics.delete_topic_hide(actor(confirmed_user_fixture()), "nonexistent", "whatever") ==
               {:error, :not_found}
    end

    test "an existing forum with an unknown topic is not found" do
      forum = forum_fixture()

      assert Topics.delete_topic_hide(
               actor(moderator_user_fixture()),
               forum.short_name,
               "nonexistent-topic"
             ) ==
               {:error, :not_found}
    end

    test "a moderator restores a hidden topic, clearing the flag, reason, and deleter" do
      # Even though the loader passes show_hidden: false, a moderator may :show a
      # hidden topic, so the visibility loader admits it and :hide then permits
      # the restore; the moderator reaches and unhides the topic.
      moderator = moderator_user_fixture()
      {forum, topic} = hidden_topic()

      assert {:ok, {loaded_forum, loaded_topic}} =
               Topics.delete_topic_hide(actor(moderator), forum.short_name, topic.slug)

      assert loaded_forum.id == forum.id
      assert loaded_topic.id == topic.id

      restored = Repo.reload!(topic)
      refute restored.hidden_from_users
      assert restored.deletion_reason == ""
      assert restored.deleted_by_id == nil
    end

    test "a successful restore writes a byte-exact moderation log" do
      moderator = moderator_user_fixture()
      {forum, topic} = hidden_topic()

      assert {:ok, _} = Topics.delete_topic_hide(actor(moderator), forum.short_name, topic.slug)

      log = latest_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Topic.Hide:delete"
      assert log.subject_path == "/forums/#{forum.short_name}/topics/#{topic.slug}"
      assert log.body == "Restored topic '#{topic.title}' in #{forum.name}"
    end
  end

  describe "create_topic_lock/4" do
    test "a regular user cannot lock a visible topic and the topic stays unlocked" do
      # The visibility loader clears a regular user on a normal, visible topic;
      # the block on the topic :hide permission is what denies the lock.
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()

      assert Topics.create_topic_lock(actor(user), forum.short_name, topic.slug, %{
               "lock_reason" => "Off topic"
             }) ==
               {:error, :unauthorized}

      assert Repo.reload!(topic).locked_at == nil
    end

    test "an anonymous actor cannot lock a visible topic" do
      # nil clears forum :show and topic visibility on normal content, but fails
      # the topic :hide permission, so this is a clean unauthorized rather than a
      # crash on the nil actor.
      {forum, topic} = visible_topic()

      assert Topics.create_topic_lock(actor(), forum.short_name, topic.slug, %{
               "lock_reason" => "Off topic"
             }) ==
               {:error, :unauthorized}

      assert Repo.reload!(topic).locked_at == nil
    end

    test "an unknown forum is unauthorized for a regular user" do
      assert Topics.create_topic_lock(
               actor(confirmed_user_fixture()),
               "nonexistent",
               "whatever",
               %{"lock_reason" => "Off topic"}
             ) == {:error, :not_found}
    end

    test "an existing forum with an unknown topic is not found" do
      forum = forum_fixture()

      assert Topics.create_topic_lock(
               actor(moderator_user_fixture()),
               forum.short_name,
               "nonexistent-topic",
               %{"lock_reason" => "Off topic"}
             ) == {:error, :not_found}
    end

    test "a moderator locks the topic, setting the timestamp, reason, and locker" do
      moderator = moderator_user_fixture()
      {forum, topic} = visible_topic()

      assert {:ok, {loaded_forum, loaded_topic}} =
               Topics.create_topic_lock(actor(moderator), forum.short_name, topic.slug, %{
                 "lock_reason" => "Off topic"
               })

      assert loaded_forum.id == forum.id
      assert loaded_topic.id == topic.id

      locked = Repo.reload!(topic)
      assert locked.locked_at != nil
      assert locked.lock_reason == "Off topic"
      assert locked.locked_by_id == moderator.id
    end

    test "a successful lock writes a byte-exact moderation log" do
      moderator = moderator_user_fixture()
      {forum, topic} = visible_topic()

      assert {:ok, _} =
               Topics.create_topic_lock(actor(moderator), forum.short_name, topic.slug, %{
                 "lock_reason" => "Off topic"
               })

      log = latest_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Topic.Lock:create"
      assert log.subject_path == "/forums/#{forum.short_name}/topics/#{topic.slug}"
      assert log.body == "Locked topic '#{topic.title}' (Off topic) in #{forum.name}"
    end

    test "a blank lock reason yields the 3-tuple error and writes no moderation log" do
      # lock_changeset requires lock_reason; create_topic_lock/4 surfaces the rejected
      # changeset as {:error, forum, topic} (both the loaded forum and the
      # pre-update topic) so the controller can still redirect.
      moderator = moderator_user_fixture()
      {forum, topic} = visible_topic()

      assert {:error, error_forum, error_topic} =
               Topics.create_topic_lock(actor(moderator), forum.short_name, topic.slug, %{
                 "lock_reason" => ""
               })

      assert error_forum.id == forum.id
      assert error_topic.id == topic.id

      assert Repo.reload!(topic).locked_at == nil
      assert moderation_log_count() == 0
    end
  end

  describe "delete_topic_lock/3" do
    test "a regular user cannot unlock a topic and it stays locked" do
      # Locking leaves the topic visible, so the loader admits a regular user,
      # who is then denied by the topic :hide permission.
      user = confirmed_user_fixture()
      {forum, topic} = locked_topic()

      assert Topics.delete_topic_lock(actor(user), forum.short_name, topic.slug) ==
               {:error, :unauthorized}

      assert Repo.reload!(topic).locked_at != nil
    end

    test "an anonymous actor cannot unlock a topic" do
      {forum, topic} = locked_topic()

      assert Topics.delete_topic_lock(actor(), forum.short_name, topic.slug) ==
               {:error, :unauthorized}

      assert Repo.reload!(topic).locked_at != nil
    end

    test "an unknown forum is unauthorized for a regular user" do
      assert Topics.delete_topic_lock(actor(confirmed_user_fixture()), "nonexistent", "whatever") ==
               {:error, :not_found}
    end

    test "an existing forum with an unknown topic is not found" do
      forum = forum_fixture()

      assert Topics.delete_topic_lock(
               actor(moderator_user_fixture()),
               forum.short_name,
               "nonexistent-topic"
             ) ==
               {:error, :not_found}
    end

    test "a moderator unlocks the topic, clearing the timestamp, reason, and locker" do
      moderator = moderator_user_fixture()
      {forum, topic} = locked_topic()

      assert {:ok, {loaded_forum, loaded_topic}} =
               Topics.delete_topic_lock(actor(moderator), forum.short_name, topic.slug)

      assert loaded_forum.id == forum.id
      assert loaded_topic.id == topic.id

      unlocked = Repo.reload!(topic)
      assert unlocked.locked_at == nil
      assert unlocked.lock_reason == ""
      assert unlocked.locked_by_id == nil
    end

    test "a successful unlock writes a byte-exact moderation log" do
      moderator = moderator_user_fixture()
      {forum, topic} = locked_topic()

      assert {:ok, _} = Topics.delete_topic_lock(actor(moderator), forum.short_name, topic.slug)

      log = latest_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Topic.Lock:delete"
      assert log.subject_path == "/forums/#{forum.short_name}/topics/#{topic.slug}"
      assert log.body == "Unlocked topic '#{topic.title}' in #{forum.name}"
    end
  end

  describe "create_topic_stick/3" do
    test "a regular user cannot stick a visible topic and the topic stays unstuck" do
      # The visibility loader clears a regular user on a normal, visible topic;
      # the block on the topic :hide permission is what denies the stick.
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()

      assert Topics.create_topic_stick(actor(user), forum.short_name, topic.slug) ==
               {:error, :unauthorized}

      refute Repo.reload!(topic).sticky
      assert moderation_log_count() == 0
    end

    test "an anonymous actor cannot stick a visible topic" do
      # nil clears forum :show and topic visibility on normal content, but fails
      # the topic :hide permission, so this is a clean unauthorized rather than a
      # crash on the nil actor.
      {forum, topic} = visible_topic()

      assert Topics.create_topic_stick(actor(), forum.short_name, topic.slug) ==
               {:error, :unauthorized}

      refute Repo.reload!(topic).sticky
      assert moderation_log_count() == 0
    end

    test "an unknown forum is unauthorized for a regular user" do
      assert Topics.create_topic_stick(actor(confirmed_user_fixture()), "nonexistent", "whatever") ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "an existing forum with an unknown topic is not found" do
      forum = forum_fixture()

      assert Topics.create_topic_stick(
               actor(moderator_user_fixture()),
               forum.short_name,
               "nonexistent-topic"
             ) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "a moderator sticks the topic, setting the sticky flag" do
      moderator = moderator_user_fixture()
      {forum, topic} = visible_topic()

      assert {:ok, {loaded_forum, loaded_topic}} =
               Topics.create_topic_stick(actor(moderator), forum.short_name, topic.slug)

      assert loaded_forum.id == forum.id
      assert loaded_topic.id == topic.id

      assert Repo.reload!(topic).sticky
    end

    test "a successful stick writes a byte-exact moderation log" do
      moderator = moderator_user_fixture()
      {forum, topic} = visible_topic()

      assert {:ok, _} = Topics.create_topic_stick(actor(moderator), forum.short_name, topic.slug)

      log = latest_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Topic.Stick:create"
      assert log.subject_path == "/forums/#{forum.short_name}/topics/#{topic.slug}"
      assert log.body == "Stickied topic '#{topic.title}' in #{forum.name}"
    end
  end

  describe "delete_topic_stick/3" do
    test "a regular user cannot unstick a topic and it stays sticky" do
      # Sticking leaves the topic visible, so the loader admits a regular user,
      # who is then denied by the topic :hide permission.
      user = confirmed_user_fixture()
      {forum, topic} = sticky_topic()

      assert Topics.delete_topic_stick(actor(user), forum.short_name, topic.slug) ==
               {:error, :unauthorized}

      assert Repo.reload!(topic).sticky
      assert moderation_log_count() == 1
    end

    test "an anonymous actor cannot unstick a topic" do
      {forum, topic} = sticky_topic()

      assert Topics.delete_topic_stick(actor(), forum.short_name, topic.slug) ==
               {:error, :unauthorized}

      assert Repo.reload!(topic).sticky
      assert moderation_log_count() == 1
    end

    test "an unknown forum is unauthorized for a regular user" do
      assert Topics.delete_topic_stick(actor(confirmed_user_fixture()), "nonexistent", "whatever") ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "an existing forum with an unknown topic is not found" do
      forum = forum_fixture()

      assert Topics.delete_topic_stick(
               actor(moderator_user_fixture()),
               forum.short_name,
               "nonexistent-topic"
             ) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "a moderator unsticks the topic, clearing the sticky flag" do
      moderator = moderator_user_fixture()
      {forum, topic} = sticky_topic()

      assert {:ok, {loaded_forum, loaded_topic}} =
               Topics.delete_topic_stick(actor(moderator), forum.short_name, topic.slug)

      assert loaded_forum.id == forum.id
      assert loaded_topic.id == topic.id

      refute Repo.reload!(topic).sticky
    end

    test "unsticking a non-sticky topic still succeeds" do
      # unstick_changeset sets the column unconditionally, so a topic that was
      # never sticky is a successful no-op rather than an error.
      moderator = moderator_user_fixture()
      {forum, topic} = visible_topic()
      refute Repo.reload!(topic).sticky

      assert {:ok, {_forum, _topic}} =
               Topics.delete_topic_stick(actor(moderator), forum.short_name, topic.slug)

      refute Repo.reload!(topic).sticky
    end

    test "a successful unstick writes a byte-exact moderation log" do
      moderator = moderator_user_fixture()
      {forum, topic} = sticky_topic()

      assert {:ok, _} = Topics.delete_topic_stick(actor(moderator), forum.short_name, topic.slug)

      log = latest_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Topic.Stick:delete"
      assert log.subject_path == "/forums/#{forum.short_name}/topics/#{topic.slug}"
      assert log.body == "Unstickied topic '#{topic.title}' in #{forum.name}"
    end
  end

  describe "create_topic_move/4" do
    test "a regular user is not found with a malformed target" do
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()

      assert Topics.create_topic_move(actor(user), forum.short_name, topic.slug, %{
               "target_forum" => "garbage"
             }) == {:error, :not_found}

      assert Repo.reload!(topic).forum_id == forum.id
      assert moderation_log_count() == 0
    end

    test "an anonymous actor is unauthorized" do
      # nil clears forum :show and topic visibility on normal content, but fails
      # the topic :hide permission, so this is a clean unauthorized.
      {forum, topic} = visible_topic()
      target = forum_fixture()

      assert Topics.create_topic_move(actor(), forum.short_name, topic.slug, %{
               "target_forum" => target.short_name
             }) == {:error, :unauthorized}

      assert Repo.reload!(topic).forum_id == forum.id
      assert moderation_log_count() == 0
    end

    test "an unknown source forum is not-found for a regular user" do
      target = forum_fixture()

      assert Topics.create_topic_move(
               actor(confirmed_user_fixture()),
               "nonexistent",
               "whatever",
               %{
                 "target_forum" => target.short_name
               }
             ) == {:error, :not_found}
    end

    test "an existing source forum with an unknown topic is not found" do
      forum = forum_fixture()
      target = forum_fixture()

      assert Topics.create_topic_move(
               actor(moderator_user_fixture()),
               forum.short_name,
               "nonexistent-topic",
               %{"target_forum" => target.short_name}
             ) == {:error, :not_found}
    end

    test "a moderator moves the topic, changing forum_id and updating both forum counts" do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)
      target = forum_fixture()

      # create_topic left the source forum at topic_count 1 and the empty target
      # at topic_count 0; the move engine's Multi shifts one topic across.
      assert Repo.reload!(forum).topic_count == 1
      assert Repo.reload!(target).topic_count == 0

      assert {:ok, {new_forum, moved_topic}} =
               Topics.create_topic_move(actor(moderator), forum.short_name, topic.slug, %{
                 "target_forum" => target.short_name
               })

      assert new_forum.id == target.id
      assert moved_topic.forum_id == target.id
      assert Repo.reload!(topic).forum_id == target.id

      assert Repo.reload!(forum).topic_count == 0
      assert Repo.reload!(target).topic_count == 1
    end

    test "a successful move writes a byte-exact moderation log against the NEW forum" do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)
      target = forum_fixture()

      assert {:ok, _} =
               Topics.create_topic_move(actor(moderator), forum.short_name, topic.slug, %{
                 "target_forum" => target.short_name
               })

      log = latest_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Topic.Move:create"
      assert log.subject_path == "/forums/#{target.short_name}/topics/#{topic.slug}"
      assert log.body == "Topic '#{topic.title}' moved to #{target.name}"
    end

    test "a slug already taken in the target forum rejects the move" do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      target = forum_fixture()
      topic = topic_fixture(forum, nil, %{"title" => "Shared title"})
      _taken = topic_fixture(target, nil, %{"title" => "Shared title"})

      assert {:error, %Forum{} = source_forum, %Topic{} = rejected_topic} =
               Topics.create_topic_move(actor(moderator), forum.short_name, topic.slug, %{
                 "target_forum" => target.short_name
               })

      assert source_forum.id == forum.id
      assert rejected_topic.id == topic.id
      assert Repo.reload!(topic).forum_id == forum.id
      assert moderation_log_count() == 0
    end

    test "a moderator with empty params gets not-found" do
      moderator = moderator_user_fixture()
      {forum, topic} = visible_topic()

      assert {:error, :not_found} =
               Topics.create_topic_move(actor(moderator), forum.short_name, topic.slug, %{})

      assert Repo.reload!(topic).forum_id == forum.id
      assert moderation_log_count() == 0
    end

    test "a moderator with a nonexistent target forum gets no move and no log" do
      moderator = moderator_user_fixture()
      {forum, topic} = visible_topic()

      assert {:error, :not_found} =
               Topics.create_topic_move(actor(moderator), forum.short_name, topic.slug, %{
                 "target_forum" => "nonexistent-forum"
               })

      assert Repo.reload!(topic).forum_id == forum.id
      assert moderation_log_count() == 0
    end
  end

  describe "show_topic_page/5" do
    test "an anonymous visitor reaches a visible topic with raw posts and both changesets" do
      {forum, topic} = visible_topic()

      assert {:ok, %TopicPage{} = page} =
               Topics.show_topic_page(actor(), forum.short_name, topic.slug, nil, @first_page)

      assert page.forum.id == forum.id
      assert page.topic.id == topic.id

      # The page entries are raw Post structs, not rendered markup.
      assert [%Post{}] = page.posts.entries
      assert page.posts.page_size == 25

      assert page.watching == false
      # A topic with no poll reports its poll as inactive.
      assert page.poll_active == false

      assert %Ecto.Changeset{} = page.post_changeset
      assert %Ecto.Changeset{} = page.topic_changeset
    end

    test "renders an empty page for a topic without post rows" do
      {forum, topic} = visible_topic()
      Repo.delete_all(where(Post, topic_id: ^topic.id))

      assert {:ok, %TopicPage{posts: %{entries: [], total_entries: 0, total_pages: 0}}} =
               Topics.show_topic_page(actor(), forum.short_name, topic.slug, nil, @first_page)
    end

    test "applies pending and destroyed post visibility before presentation" do
      viewer = confirmed_user_fixture()
      {forum, topic} = visible_topic()

      approved = post_fixture(topic, confirmed_user_fixture(), %{"body" => "approved"})

      own_pending =
        post_fixture(topic, viewer, %{"body" => "own pending"})
        |> Ecto.Changeset.change(approved: false)
        |> Repo.update!()

      ip_pending =
        post_fixture(topic, confirmed_user_fixture(), %{"body" => "same ip pending"})
        |> Ecto.Changeset.change(approved: false, ip: actor(viewer).ip)
        |> Repo.update!()

      other_pending =
        post_fixture(topic, confirmed_user_fixture(), %{"body" => "other pending"})
        |> Ecto.Changeset.change(approved: false, ip: random_ip())
        |> Repo.update!()

      destroyed =
        post_fixture(topic, confirmed_user_fixture(), %{"body" => "destroyed"})
        |> Ecto.Changeset.change(destroyed_content: true)
        |> Repo.update!()

      assert {:ok, page} =
               Topics.show_topic_page(
                 actor(viewer),
                 forum.short_name,
                 topic.slug,
                 nil,
                 @first_page
               )

      ids = Enum.map(page.posts.entries, & &1.id)
      assert approved.id in ids
      assert own_pending.id in ids
      assert ip_pending.id in ids
      refute other_pending.id in ids
      refute destroyed.id in ids
    end

    test "a moderator receives pending and destroyed posts from the page loader" do
      {forum, topic} = visible_topic()

      pending =
        post_fixture(topic, confirmed_user_fixture())
        |> Ecto.Changeset.change(approved: false)
        |> Repo.update!()

      destroyed =
        post_fixture(topic, confirmed_user_fixture())
        |> Ecto.Changeset.change(destroyed_content: true)
        |> Repo.update!()

      assert {:ok, page} =
               Topics.show_topic_page(
                 actor(moderator_user_fixture()),
                 forum.short_name,
                 topic.slug,
                 nil,
                 @first_page
               )

      ids = Enum.map(page.posts.entries, & &1.id)
      assert pending.id in ids
      assert destroyed.id in ids
    end

    test "a hidden topic is unauthorized for a regular user" do
      user = confirmed_user_fixture()
      {forum, topic} = hidden_topic()

      assert Topics.show_topic_page(actor(user), forum.short_name, topic.slug, nil, @first_page) ==
               {:error, :unauthorized}
    end

    test "an unknown forum is unauthorized for a regular user" do
      assert Topics.show_topic_page(
               actor(confirmed_user_fixture()),
               "nonexistent",
               "whatever",
               nil,
               @first_page
             ) == {:error, :not_found}
    end

    test "an existing forum with an unknown topic is not found" do
      forum = forum_fixture()

      assert Topics.show_topic_page(
               actor(confirmed_user_fixture()),
               forum.short_name,
               "nonexistent-topic",
               nil,
               @first_page
             ) == {:error, :not_found}
    end

    test "a post_id naming a post on the second page derives that page over the pagination" do
      # The first post sits at topic_position 0; 25 replies fill positions 1..25,
      # so the last reply falls on page 2 (div(25, 25) + 1) even though the
      # pagination map asks for page 1.
      {forum, topic} = visible_topic()

      replies = for _ <- 1..25, do: post_fixture(topic)
      last = List.last(replies)
      assert last.topic_position == 25

      assert {:ok, page} =
               Topics.show_topic_page(
                 actor(),
                 forum.short_name,
                 topic.slug,
                 to_string(last.id),
                 %{
                   page_number: 1,
                   page_size: 25
                 }
               )

      assert page.posts.page_number == 2
      assert Enum.map(page.posts.entries, & &1.id) == [last.id]
    end

    test "pages cover every position when a destroyed post leaves post_count" do
      {forum, topic} = visible_topic()
      moderator = actor(moderator_user_fixture())
      [destroyed | _] = for _ <- 1..25, do: post_fixture(topic)

      {:ok, _} =
        Posts.create_post_hide(moderator, forum.short_name, topic.slug, "#{destroyed.id}", %{
          "deletion_reason" => "Spam"
        })

      {:ok, _} =
        Posts.create_post_delete(moderator, forum.short_name, topic.slug, "#{destroyed.id}")

      assert Repo.reload!(topic).post_count == 25

      assert {:ok, page} =
               Topics.show_topic_page(actor(), forum.short_name, topic.slug, nil, @first_page)

      assert page.posts.total_entries == 26
      assert page.posts.total_pages == 2
    end

    test "a subscribed user has watching set true" do
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()
      {:ok, _} = Topics.create_subscription(topic, user)

      assert {:ok, page} =
               Topics.show_topic_page(actor(user), forum.short_name, topic.slug, nil, @first_page)

      assert page.watching
    end

    test "loading the page clears the user's topic notification" do
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()

      {:ok, _} = Topics.create_subscription(topic, user)
      author = confirmed_user_fixture()
      post = hd(topic.posts)
      {:ok, 1} = Notifications.broadcast_forum_post(author, topic, post)
      assert post_notification?(topic, user)

      assert {:ok, _page} =
               Topics.show_topic_page(actor(user), forum.short_name, topic.slug, nil, @first_page)

      refute post_notification?(topic, user)
    end
  end

  describe "new_topic/2" do
    test "a banned actor is rejected before any loading" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Topics.new_topic(actor, "nonexistent") == {:error, :ban}
    end

    test "a regular actor gets the forum and a changeset seeded with a poll and one post" do
      forum = forum_fixture()

      actor = actor(confirmed_user_fixture(), fingerprint: nil)

      assert {:ok, {loaded_forum, changeset}} = Topics.new_topic(actor, forum.short_name)

      assert loaded_forum.id == forum.id
      assert %Ecto.Changeset{} = changeset
      assert length(changeset.data.poll.options) == 2
      assert length(changeset.data.posts) == 1
    end

    test "an unknown forum is unauthorized for a regular actor" do
      assert Topics.new_topic(actor(confirmed_user_fixture()), "nonexistent") ==
               {:error, :not_found}
    end
  end

  describe "create_topic/3" do
    @valid_topic_params %{
      "title" => "A brand new topic",
      "anonymous" => "false",
      "posts" => %{"0" => %{"body" => "First post body"}}
    }

    test "a banned actor is rejected before any loading" do
      # verify_write_access runs first, so a banned actor is {:error, :ban} even
      # against a forum slug that does not exist.
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Topics.create_topic(actor, "nonexistent", @valid_topic_params) == {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized before any loading" do
      actor = actor(confirmed_user_fixture(), fingerprint: nil)

      assert Topics.create_topic(actor, "nonexistent", @valid_topic_params) ==
               {:error, :unauthorized}
    end

    test "a valid signed-in actor creates the topic with its first post" do
      forum = forum_fixture()
      user = confirmed_user_fixture()

      assert {:ok, %{topic: topic, forum: loaded_forum, post: post}} =
               Topics.create_topic(actor(user), forum.short_name, @valid_topic_params)

      assert loaded_forum.id == forum.id
      assert topic.title == "A brand new topic"
      assert topic.user_id == user.id
      assert post.topic_id == topic.id

      assert Repo.get(Topic, topic.id)
      assert Repo.reload!(post).body == "First post body"
    end

    test "an approved initial post increments the author's posts_count" do
      forum = forum_fixture()
      author = confirmed_user_fixture()
      before = Repo.get!(User, author.id).posts_count

      assert {:ok, %{topic: _topic, post: post}} =
               Topics.create_topic(actor(author), forum.short_name, @valid_topic_params)

      assert post.approved
      assert Repo.get!(User, author.id).posts_count == before + 1
    end

    test "a withheld initial post does not decrement the author's posts_count" do
      forum = forum_fixture()
      author = confirmed_user_fixture()
      before = Repo.get!(User, author.id).posts_count

      rule_fixture()
      |> Ecto.Changeset.change(name: "Approval")
      |> Repo.update!()

      params =
        put_in(@valid_topic_params, ["posts", "0", "body"], "First post https://spam.example/")

      assert {:ok, %{topic: _topic, post: post}} =
               Topics.create_topic(actor(author), forum.short_name, params)

      refute post.approved
      assert Repo.get!(User, author.id).posts_count == before
      assert Repo.aggregate(from(r in Report, where: r.post_id == ^post.id), :count) == 1
    end

    test "blank params yield the changeset error carrying the forum" do
      forum = forum_fixture()
      user = confirmed_user_fixture()

      params = %{
        "title" => "",
        "anonymous" => "false",
        "posts" => %{"0" => %{"body" => ""}}
      }

      assert {:error, error_forum, %Ecto.Changeset{}} =
               Topics.create_topic(actor(user), forum.short_name, params)

      assert error_forum.id == forum.id
    end

    test "an unknown forum is unauthorized for a valid actor" do
      assert Topics.create_topic(
               actor(confirmed_user_fixture()),
               "nonexistent",
               @valid_topic_params
             ) == {:error, :not_found}
    end

    test "an over-limit actor is rate limited and no topic is created" do
      # The :topic_create counter is primed past the limit, so the rate check
      # (after write-access, before the forum load and insert) refuses the write.
      forum = forum_fixture()
      actor = actor(confirmed_user_fixture())
      exceed_rate_limit(actor, :topic_create)

      assert Topics.create_topic(actor, forum.short_name, @valid_topic_params) ==
               {:error, :rate_limited}

      assert Repo.aggregate(from(t in Topic, where: t.forum_id == ^forum.id), :count) == 0
    end

    test "a successful create records the counter" do
      forum = forum_fixture()
      actor = actor(confirmed_user_fixture())
      track_rate_limit(actor, :topic_create)

      assert {:ok, %{topic: %Topic{}}} =
               Topics.create_topic(actor, forum.short_name, @valid_topic_params)

      assert rate_limit_count(actor, :topic_create) == "1"
    end

    test "the rate check precedes the forum load: over-limit against an unknown forum is still rate limited" do
      # load_authorized_forum runs after the rate check, so an over-limit actor
      # gets :rate_limited rather than the :unauthorized a missing forum yields.
      actor = actor(confirmed_user_fixture())
      exceed_rate_limit(actor, :topic_create)

      assert Topics.create_topic(actor, "nonexistent", @valid_topic_params) ==
               {:error, :rate_limited}
    end
  end

  describe "update_topic/4" do
    test "a regular user cannot edit a topic title and it stays unchanged" do
      user = confirmed_user_fixture()
      {forum, topic} = visible_topic()

      assert Topics.update_topic(actor(user), forum.short_name, topic.slug, %{
               "title" => "New Title"
             }) == {:error, :unauthorized}

      assert Repo.reload!(topic).title == topic.title
    end

    test "a moderator updates the title" do
      moderator = moderator_user_fixture()
      {forum, topic} = visible_topic()

      assert {:ok, {loaded_forum, updated_topic}} =
               Topics.update_topic(actor(moderator), forum.short_name, topic.slug, %{
                 "title" => "Renamed topic"
               })

      assert loaded_forum.id == forum.id
      assert updated_topic.title == "Renamed topic"
      assert Repo.reload!(topic).title == "Renamed topic"
    end

    test "a blank title yields the 3-tuple error and leaves the title unchanged" do
      # title_changeset requires the title, so a blank one surfaces as
      # {:error, forum, topic} (both the loaded forum and the pre-update topic).
      moderator = moderator_user_fixture()
      {forum, topic} = visible_topic()
      original_title = topic.title

      assert {:error, error_forum, error_topic} =
               Topics.update_topic(actor(moderator), forum.short_name, topic.slug, %{
                 "title" => ""
               })

      assert error_forum.id == forum.id
      assert error_topic.id == topic.id
      assert Repo.reload!(topic).title == original_title
    end

    test "an existing forum with an unknown topic is not found" do
      forum = forum_fixture()

      assert Topics.update_topic(
               actor(moderator_user_fixture()),
               forum.short_name,
               "nonexistent-topic",
               %{"title" => "New Title"}
             ) == {:error, :not_found}
    end
  end
end
