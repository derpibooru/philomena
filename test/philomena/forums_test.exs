defmodule Philomena.ForumsTest do
  use Philomena.DataCase

  alias Philomena.Forums

  describe "forums" do
    alias Philomena.Forums.Forum

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def forum_fixture(attrs \\ %{}) do
      {:ok, forum} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Forums.create_forum()

      forum
    end

    test "list_forums/0 returns all forums" do
      forum = forum_fixture()
      assert Forums.list_forums() == [forum]
    end

    test "get_forum!/1 returns the forum with given id" do
      forum = forum_fixture()
      assert Forums.get_forum!(forum.id) == forum
    end

    test "create_forum/1 with valid data creates a forum" do
      assert {:ok, %Forum{} = forum} = Forums.create_forum(@valid_attrs)
    end

    test "create_forum/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Forums.create_forum(@invalid_attrs)
    end

    test "update_forum/2 with valid data updates the forum" do
      forum = forum_fixture()
      assert {:ok, %Forum{} = forum} = Forums.update_forum(forum, @update_attrs)
    end

    test "update_forum/2 with invalid data returns error changeset" do
      forum = forum_fixture()
      assert {:error, %Ecto.Changeset{}} = Forums.update_forum(forum, @invalid_attrs)
      assert forum == Forums.get_forum!(forum.id)
    end

    test "delete_forum/1 deletes the forum" do
      forum = forum_fixture()
      assert {:ok, %Forum{}} = Forums.delete_forum(forum)
      assert_raise Ecto.NoResultsError, fn -> Forums.get_forum!(forum.id) end
    end

    test "change_forum/1 returns a forum changeset" do
      forum = forum_fixture()
      assert %Ecto.Changeset{} = Forums.change_forum(forum)
    end
  end

  describe "topics" do
    alias Philomena.Forums.Topic

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def topic_fixture(attrs \\ %{}) do
      {:ok, topic} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Forums.create_topic()

      topic
    end

    test "list_topics/0 returns all topics" do
      topic = topic_fixture()
      assert Forums.list_topics() == [topic]
    end

    test "get_topic!/1 returns the topic with given id" do
      topic = topic_fixture()
      assert Forums.get_topic!(topic.id) == topic
    end

    test "create_topic/1 with valid data creates a topic" do
      assert {:ok, %Topic{} = topic} = Forums.create_topic(@valid_attrs)
    end

    test "create_topic/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Forums.create_topic(@invalid_attrs)
    end

    test "update_topic/2 with valid data updates the topic" do
      topic = topic_fixture()
      assert {:ok, %Topic{} = topic} = Forums.update_topic(topic, @update_attrs)
    end

    test "update_topic/2 with invalid data returns error changeset" do
      topic = topic_fixture()
      assert {:error, %Ecto.Changeset{}} = Forums.update_topic(topic, @invalid_attrs)
      assert topic == Forums.get_topic!(topic.id)
    end

    test "delete_topic/1 deletes the topic" do
      topic = topic_fixture()
      assert {:ok, %Topic{}} = Forums.delete_topic(topic)
      assert_raise Ecto.NoResultsError, fn -> Forums.get_topic!(topic.id) end
    end

    test "change_topic/1 returns a topic changeset" do
      topic = topic_fixture()
      assert %Ecto.Changeset{} = Forums.change_topic(topic)
    end
  end

  describe "posts" do
    alias Philomena.Forums.Post

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def post_fixture(attrs \\ %{}) do
      {:ok, post} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Forums.create_post()

      post
    end

    test "list_posts/0 returns all posts" do
      post = post_fixture()
      assert Forums.list_posts() == [post]
    end

    test "get_post!/1 returns the post with given id" do
      post = post_fixture()
      assert Forums.get_post!(post.id) == post
    end

    test "create_post/1 with valid data creates a post" do
      assert {:ok, %Post{} = post} = Forums.create_post(@valid_attrs)
    end

    test "create_post/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Forums.create_post(@invalid_attrs)
    end

    test "update_post/2 with valid data updates the post" do
      post = post_fixture()
      assert {:ok, %Post{} = post} = Forums.update_post(post, @update_attrs)
    end

    test "update_post/2 with invalid data returns error changeset" do
      post = post_fixture()
      assert {:error, %Ecto.Changeset{}} = Forums.update_post(post, @invalid_attrs)
      assert post == Forums.get_post!(post.id)
    end

    test "delete_post/1 deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Forums.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Forums.get_post!(post.id) end
    end

    test "change_post/1 returns a post changeset" do
      post = post_fixture()
      assert %Ecto.Changeset{} = Forums.change_post(post)
    end
  end

  describe "forum_subscriptions" do
    alias Philomena.Forums.Subscription

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def subscription_fixture(attrs \\ %{}) do
      {:ok, subscription} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Forums.create_subscription()

      subscription
    end

    test "list_forum_subscriptions/0 returns all forum_subscriptions" do
      subscription = subscription_fixture()
      assert Forums.list_forum_subscriptions() == [subscription]
    end

    test "get_subscription!/1 returns the subscription with given id" do
      subscription = subscription_fixture()
      assert Forums.get_subscription!(subscription.id) == subscription
    end

    test "create_subscription/1 with valid data creates a subscription" do
      assert {:ok, %Subscription{} = subscription} = Forums.create_subscription(@valid_attrs)
    end

    test "create_subscription/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Forums.create_subscription(@invalid_attrs)
    end

    test "update_subscription/2 with valid data updates the subscription" do
      subscription = subscription_fixture()
      assert {:ok, %Subscription{} = subscription} = Forums.update_subscription(subscription, @update_attrs)
    end

    test "update_subscription/2 with invalid data returns error changeset" do
      subscription = subscription_fixture()
      assert {:error, %Ecto.Changeset{}} = Forums.update_subscription(subscription, @invalid_attrs)
      assert subscription == Forums.get_subscription!(subscription.id)
    end

    test "delete_subscription/1 deletes the subscription" do
      subscription = subscription_fixture()
      assert {:ok, %Subscription{}} = Forums.delete_subscription(subscription)
      assert_raise Ecto.NoResultsError, fn -> Forums.get_subscription!(subscription.id) end
    end

    test "change_subscription/1 returns a subscription changeset" do
      subscription = subscription_fixture()
      assert %Ecto.Changeset{} = Forums.change_subscription(subscription)
    end
  end

  describe "polls" do
    alias Philomena.Forums.Polls

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def polls_fixture(attrs \\ %{}) do
      {:ok, polls} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Forums.create_polls()

      polls
    end

    test "list_polls/0 returns all polls" do
      polls = polls_fixture()
      assert Forums.list_polls() == [polls]
    end

    test "get_polls!/1 returns the polls with given id" do
      polls = polls_fixture()
      assert Forums.get_polls!(polls.id) == polls
    end

    test "create_polls/1 with valid data creates a polls" do
      assert {:ok, %Polls{} = polls} = Forums.create_polls(@valid_attrs)
    end

    test "create_polls/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Forums.create_polls(@invalid_attrs)
    end

    test "update_polls/2 with valid data updates the polls" do
      polls = polls_fixture()
      assert {:ok, %Polls{} = polls} = Forums.update_polls(polls, @update_attrs)
    end

    test "update_polls/2 with invalid data returns error changeset" do
      polls = polls_fixture()
      assert {:error, %Ecto.Changeset{}} = Forums.update_polls(polls, @invalid_attrs)
      assert polls == Forums.get_polls!(polls.id)
    end

    test "delete_polls/1 deletes the polls" do
      polls = polls_fixture()
      assert {:ok, %Polls{}} = Forums.delete_polls(polls)
      assert_raise Ecto.NoResultsError, fn -> Forums.get_polls!(polls.id) end
    end

    test "change_polls/1 returns a polls changeset" do
      polls = polls_fixture()
      assert %Ecto.Changeset{} = Forums.change_polls(polls)
    end
  end

  describe "poll_votes" do
    alias Philomena.Forums.PollVote

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def poll_vote_fixture(attrs \\ %{}) do
      {:ok, poll_vote} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Forums.create_poll_vote()

      poll_vote
    end

    test "list_poll_votes/0 returns all poll_votes" do
      poll_vote = poll_vote_fixture()
      assert Forums.list_poll_votes() == [poll_vote]
    end

    test "get_poll_vote!/1 returns the poll_vote with given id" do
      poll_vote = poll_vote_fixture()
      assert Forums.get_poll_vote!(poll_vote.id) == poll_vote
    end

    test "create_poll_vote/1 with valid data creates a poll_vote" do
      assert {:ok, %PollVote{} = poll_vote} = Forums.create_poll_vote(@valid_attrs)
    end

    test "create_poll_vote/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Forums.create_poll_vote(@invalid_attrs)
    end

    test "update_poll_vote/2 with valid data updates the poll_vote" do
      poll_vote = poll_vote_fixture()
      assert {:ok, %PollVote{} = poll_vote} = Forums.update_poll_vote(poll_vote, @update_attrs)
    end

    test "update_poll_vote/2 with invalid data returns error changeset" do
      poll_vote = poll_vote_fixture()
      assert {:error, %Ecto.Changeset{}} = Forums.update_poll_vote(poll_vote, @invalid_attrs)
      assert poll_vote == Forums.get_poll_vote!(poll_vote.id)
    end

    test "delete_poll_vote/1 deletes the poll_vote" do
      poll_vote = poll_vote_fixture()
      assert {:ok, %PollVote{}} = Forums.delete_poll_vote(poll_vote)
      assert_raise Ecto.NoResultsError, fn -> Forums.get_poll_vote!(poll_vote.id) end
    end

    test "change_poll_vote/1 returns a poll_vote changeset" do
      poll_vote = poll_vote_fixture()
      assert %Ecto.Changeset{} = Forums.change_poll_vote(poll_vote)
    end
  end
end
