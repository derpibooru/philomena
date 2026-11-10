defmodule Philomena.ForumHierarchyConcurrencyTest do
  use Philomena.ConcurrentDataCase

  import Ecto.Query
  import Philomena.AttributionFixtures
  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.RulesFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Posts
  alias Philomena.Posts.Post
  alias Philomena.Repo
  alias Philomena.Topics
  alias Philomena.Topics.Topic
  alias Philomena.Users.User

  defp forum_post_ids(forum_id) do
    Repo.all(
      from post in Post,
        join: topic in Topic,
        on: topic.id == post.topic_id,
        where:
          topic.forum_id == ^forum_id and not topic.hidden_from_users and
            not post.destroyed_content,
        select: post.id
    )
  end

  defp forum_visible_post_ids(forum_id) do
    Repo.all(
      from post in Post,
        join: topic in Topic,
        on: topic.id == post.topic_id,
        where:
          topic.forum_id == ^forum_id and not topic.hidden_from_users and
            not post.hidden_from_users and not post.destroyed_content,
        select: post.id
    )
  end

  defp assert_forum_caches(forum) do
    forum = Repo.reload!(forum)

    topic_count =
      Repo.aggregate(
        from(topic in Topic, where: topic.forum_id == ^forum.id and not topic.hidden_from_users),
        :count
      )

    post_ids = forum_post_ids(forum.id)
    visible_post_ids = forum_visible_post_ids(forum.id)

    assert forum.topic_count == topic_count
    assert forum.post_count == length(post_ids)
    assert forum.last_post_id == Enum.max(visible_post_ids, fn -> nil end)
  end

  defp assert_topic_caches(topic) do
    topic = Repo.reload!(topic)

    post_ids =
      Repo.all(
        from post in Post,
          where: post.topic_id == ^topic.id and not post.destroyed_content,
          select: post.id
      )

    visible_post_ids =
      Repo.all(
        from post in Post,
          where:
            post.topic_id == ^topic.id and not post.hidden_from_users and
              not post.destroyed_content,
          select: post.id
      )

    assert topic.post_count == length(post_ids)
    assert topic.last_post_id == Enum.max(visible_post_ids, fn -> nil end)
  end

  defp approval_rule! do
    rule_fixture()
    |> Ecto.Changeset.change(name: "Approval")
    |> Repo.update!()
  end

  test "concurrent replies preserve topic and forum counters and latest-post caches" do
    forum = forum_fixture()
    topic = topic_fixture(forum)

    functions =
      for index <- 1..8 do
        user = confirmed_user_fixture()
        actor = actor(user, ip: random_ip())

        fn ->
          Posts.create_post(actor, forum.short_name, topic.slug, %{
            "body" => "Concurrent reply #{index}"
          })
        end
      end

    results = concurrently(functions)

    assert Enum.all?(results, &match?({:ok, %Post{}}, &1))
    assert_topic_caches(topic)
    assert_forum_caches(forum)
  end

  test "concurrent topic creation preserves forum counters and latest-post cache" do
    forum = forum_fixture()

    functions =
      for index <- 1..8 do
        user = confirmed_user_fixture()
        actor = actor(user, ip: random_ip())

        fn ->
          Topics.create_topic(actor, forum.short_name, %{
            "title" => "Concurrent topic #{index}",
            "anonymous" => "false",
            "posts" => %{"0" => %{"body" => "Concurrent topic body #{index}"}}
          })
        end
      end

    results = concurrently(functions)

    assert Enum.all?(results, &match?({:ok, %{topic: %Topic{}}}, &1))
    assert_forum_caches(forum)

    for topic <- Repo.all(from topic in Topic, where: topic.forum_id == ^forum.id) do
      assert_topic_caches(topic)
    end
  end

  test "moving a topic to a restricted forum races post creation without stale caches" do
    source = forum_fixture()
    target = forum_fixture(access_level: "staff")
    topic = topic_fixture(source)
    moderator = actor(moderator_user_fixture(), ip: random_ip())
    author = actor(confirmed_user_fixture(), ip: random_ip())

    [move_result, post_result] =
      concurrently([
        fn ->
          Topics.create_topic_move(moderator, source.short_name, topic.slug, %{
            "target_forum" => target.short_name
          })
        end,
        fn ->
          Posts.create_post(author, source.short_name, topic.slug, %{
            "body" => "Reply racing a forum move"
          })
        end
      ])

    assert move_result == {:error, :not_found} or match?({:ok, _}, move_result)

    assert post_result == {:error, :unauthorized} or
             post_result == {:error, :not_found} or
             match?({:ok, _}, post_result)

    assert_forum_caches(source)
    assert_forum_caches(target)
    assert_topic_caches(topic)
  end

  test "opposite-direction forum moves use a consistent two-forum lock order" do
    forum_a = forum_fixture(short_name: "a" <> unique_forum_short_name())
    forum_b = forum_fixture(short_name: "b" <> unique_forum_short_name())
    topic_a = topic_fixture(forum_a)
    topic_b = topic_fixture(forum_b)
    moderator = actor(moderator_user_fixture(), ip: random_ip())

    [a_to_b_result, b_to_a_result] =
      concurrently([
        fn ->
          Topics.create_topic_move(moderator, forum_a.short_name, topic_a.slug, %{
            "target_forum" => forum_b.short_name
          })
        end,
        fn ->
          Topics.create_topic_move(moderator, forum_b.short_name, topic_b.slug, %{
            "target_forum" => forum_a.short_name
          })
        end
      ])

    assert match?({:ok, {%{id: _, short_name: _}, %{id: _, slug: _}}}, a_to_b_result)
    assert match?({:ok, {%{id: _, short_name: _}, %{id: _, slug: _}}}, b_to_a_result)
    assert Repo.reload!(topic_a).forum_id == forum_b.id
    assert Repo.reload!(topic_b).forum_id == forum_a.id
    assert_forum_caches(forum_a)
    assert_forum_caches(forum_b)
    assert_topic_caches(topic_a)
    assert_topic_caches(topic_b)
  end

  test "locking a topic races post creation without bypassing authorization or counters" do
    forum = forum_fixture()
    topic = topic_fixture(forum)
    moderator = actor(moderator_user_fixture(), ip: random_ip())
    author = actor(confirmed_user_fixture(), ip: random_ip())

    [lock_result, post_result] =
      concurrently([
        fn ->
          Topics.create_topic_lock(moderator, forum.short_name, topic.slug, %{
            "lock_reason" => "Concurrent lock"
          })
        end,
        fn ->
          Posts.create_post(author, forum.short_name, topic.slug, %{
            "body" => "Reply racing a topic lock"
          })
        end
      ])

    assert match?({:ok, _}, lock_result)
    assert post_result == {:error, :unauthorized} or match?({:ok, _}, post_result)

    assert Repo.reload!(topic).locked_at
    assert_topic_caches(topic)
    assert_forum_caches(forum)
  end

  test "destroying a post in a hidden topic keeps counters correct through restore" do
    forum = forum_fixture()
    topic = topic_fixture(forum)
    post = hd(topic.posts)
    moderator = actor(moderator_user_fixture(), ip: random_ip())

    assert Repo.reload!(topic).post_count == 1
    assert Repo.reload!(forum).post_count == 1

    assert {:ok, _} =
             Topics.create_topic_hide(moderator, forum.short_name, topic.slug, %{
               "deletion_reason" => "Hidden for moderation"
             })

    assert Repo.reload!(topic).post_count == 1
    assert Repo.reload!(forum).post_count == 0

    assert {:ok, _} =
             Posts.create_post_hide(
               moderator,
               forum.short_name,
               topic.slug,
               post.id,
               %{"deletion_reason" => "Destroyed post"}
             )

    assert {:ok, _} = Posts.create_post_delete(moderator, forum.short_name, topic.slug, post.id)

    assert_topic_caches(topic)
    assert_forum_caches(forum)

    assert {:ok, _} = Topics.delete_topic_hide(moderator, forum.short_name, topic.slug)

    assert_topic_caches(topic)
    assert_forum_caches(forum)
  end

  test "approval racing destruction leaves one counter update and the correct latest post" do
    forum = forum_fixture()
    topic = topic_fixture(forum)
    approval_rule!()
    author = confirmed_user_fixture()

    post =
      post_fixture(topic, author, %{
        "body" => "Pending post https://spam.example/"
      })

    refute post.approved
    moderator = actor(moderator_user_fixture(), ip: random_ip())
    destroyer = actor(moderator_user_fixture(), ip: random_ip())

    assert {:ok, %Post{hidden_from_users: true}} =
             Posts.create_post_hide(
               moderator,
               forum.short_name,
               topic.slug,
               post.id,
               %{"deletion_reason" => "Pending moderation"}
             )

    before_posts_count = Repo.get!(User, author.id).posts_count

    [approval_result, destroy_result] =
      concurrently([
        fn -> Posts.create_post_approve(moderator, forum.short_name, topic.slug, post.id) end,
        fn -> Posts.create_post_delete(destroyer, forum.short_name, topic.slug, post.id) end
      ])

    assert match?({:ok, %Post{}}, destroy_result)

    assert match?({:error, %Ecto.Changeset{}}, approval_result) or
             match?({:ok, %Post{}}, approval_result)

    reloaded_post = Repo.reload!(post)
    assert reloaded_post.destroyed_content
    assert Repo.get!(User, author.id).posts_count == before_posts_count
    assert_topic_caches(topic)
    assert_forum_caches(forum)
  end

  test "destruction racing unhiding serializes the hidden-post transition" do
    forum = forum_fixture()
    topic = topic_fixture(forum)
    author = confirmed_user_fixture()
    post = post_fixture(topic, author)
    moderator = actor(moderator_user_fixture(), ip: random_ip())
    unhide_actor = actor(moderator_user_fixture(), ip: random_ip())

    assert {:ok, %Post{hidden_from_users: true}} =
             Posts.create_post_hide(
               moderator,
               forum.short_name,
               topic.slug,
               post.id,
               %{"deletion_reason" => "Pending destruction"}
             )

    [destroy_result, unhide_result] =
      concurrently([
        fn -> Posts.create_post_delete(moderator, forum.short_name, topic.slug, post.id) end,
        fn -> Posts.delete_post_hide(unhide_actor, forum.short_name, topic.slug, post.id) end
      ])

    assert Enum.count([destroy_result, unhide_result], &match?({:ok, %Post{}}, &1)) == 1

    assert match?({:ok, %Post{}}, destroy_result) or
             match?({:error, %Ecto.Changeset{}}, destroy_result)

    assert match?({:ok, %Post{}}, unhide_result) or
             match?({:error, %Ecto.Changeset{}}, unhide_result)

    reloaded_post = Repo.reload!(post)

    if reloaded_post.destroyed_content do
      assert reloaded_post.hidden_from_users
    else
      refute reloaded_post.hidden_from_users
    end

    assert_topic_caches(topic)
    assert_forum_caches(forum)
  end
end
