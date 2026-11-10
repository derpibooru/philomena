defmodule Philomena.NotificationsTest do
  use Philomena.DataCase, async: true

  alias Philomena.Channels
  alias Philomena.Galleries
  alias Philomena.Images
  alias Philomena.Notifications
  alias Philomena.Notifications.ChannelLiveNotification
  alias Philomena.Notifications.ForumPostNotification
  alias Philomena.Notifications.ForumTopicNotification
  alias Philomena.Notifications.GalleryImageNotification
  alias Philomena.Notifications.ImageCommentNotification
  alias Philomena.Notifications.ImageMergeNotification
  alias Philomena.Topics

  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1]
  import Philomena.ChannelsFixtures
  import Philomena.CommentsFixtures
  import Philomena.ForumsFixtures
  import Philomena.GalleriesFixtures
  import Philomena.ImagesFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  @categories ~w(channel_live forum_post forum_topic gallery_image image_comment image_merge)
  @pagination %{page_number: 1, page_size: 10}

  defp event_cases(subscriber, author) do
    channel = channel_fixture()
    {:ok, _subscription} = Channels.create_subscription(channel, subscriber)

    forum = forum_fixture()
    forum_topic = topic_fixture(forum, author)
    {:ok, _subscription} = Philomena.Forums.create_subscription(forum, subscriber)

    post_topic = forum_fixture() |> topic_fixture(author)
    post = post_fixture(post_topic, author)
    {:ok, _subscription} = Topics.create_subscription(post_topic, subscriber)

    gallery = gallery_fixture(author)
    {:ok, _subscription} = Galleries.create_subscription(gallery, subscriber)

    comment_image = image_fixture()
    comment = comment_fixture(comment_image, author)
    {:ok, _subscription} = Images.create_subscription(comment_image, subscriber)

    merge_target = image_fixture()
    merge_source = image_fixture()
    {:ok, _subscription} = Images.create_subscription(merge_target, subscriber)

    [
      %{
        category: :channel_live,
        schema: ChannelLiveNotification,
        broadcast: fn -> Notifications.broadcast_channel_live(channel) end,
        clear: fn -> Notifications.clear_channel_live(channel, subscriber) end
      },
      %{
        category: :forum_post,
        schema: ForumPostNotification,
        broadcast: fn -> Notifications.broadcast_forum_post(author, post_topic, post) end,
        clear: fn -> Notifications.clear_forum_post(post_topic, subscriber) end
      },
      %{
        category: :forum_topic,
        schema: ForumTopicNotification,
        broadcast: fn -> Notifications.broadcast_forum_topic(author, forum_topic) end,
        clear: fn -> Notifications.clear_forum_topic(forum_topic, subscriber) end
      },
      %{
        category: :gallery_image,
        schema: GalleryImageNotification,
        broadcast: fn -> Notifications.broadcast_gallery_image(gallery) end,
        clear: fn -> Notifications.clear_gallery_image(gallery, subscriber) end
      },
      %{
        category: :image_comment,
        schema: ImageCommentNotification,
        broadcast: fn -> Notifications.broadcast_image_comment(author, comment_image, comment) end,
        clear: fn -> Notifications.clear_image_comment(comment_image, subscriber) end
      },
      %{
        category: :image_merge,
        schema: ImageMergeNotification,
        broadcast: fn -> Notifications.broadcast_image_merge(merge_target, merge_source) end,
        clear: fn -> Notifications.clear_image_merge(merge_target, subscriber) end
      }
    ]
  end

  describe "parse_category/1" do
    test "normalizes every recognized route parameter" do
      for category <- @categories do
        assert Notifications.parse_category(category) == {:ok, String.to_existing_atom(category)}
      end
    end

    test "rejects unknown and non-string route parameters" do
      for param <- ["bogus", "", nil, 42] do
        assert Notifications.parse_category(param) == {:error, :not_found}
      end
    end
  end

  describe "actor-scoped unread reads" do
    test "returns every category and never surfaces another user's rows" do
      subscriber = confirmed_user_fixture()
      other = confirmed_user_fixture()
      channel = channel_fixture()
      {:ok, _subscription} = Channels.create_subscription(channel, subscriber)
      assert {:ok, 1} = Notifications.broadcast_channel_live(channel)

      assert {:ok, notifications} =
               Notifications.list_unread_notifications(actor(subscriber), @pagination)

      assert Keyword.keys(notifications) == Enum.map(@categories, &String.to_existing_atom/1)
      assert [%ChannelLiveNotification{}] = notifications[:channel_live].entries
      assert Notifications.total_unread_count(actor(subscriber)) == 1

      assert {:ok, other_notifications} =
               Notifications.list_unread_notifications(actor(other), @pagination)

      assert Enum.all?(other_notifications, fn {_category, page} -> page.entries == [] end)
      assert Notifications.total_unread_count(actor(other)) == 0
    end

    test "defines anonymous behavior explicitly" do
      assert Notifications.total_unread_count(actor()) == 0

      assert Notifications.list_unread_notifications(actor(), @pagination) ==
               {:error, :unauthorized}

      assert Notifications.show_unread_notification_category(actor(), "forum_post", @pagination) ==
               {:error, :unauthorized}
    end

    test "parses and paginates a single category" do
      subscriber = confirmed_user_fixture()

      for _ <- 1..2 do
        channel = channel_fixture()
        {:ok, _subscription} = Channels.create_subscription(channel, subscriber)
        assert {:ok, 1} = Notifications.broadcast_channel_live(channel)
      end

      assert {:ok, {:channel_live, page}} =
               Notifications.show_unread_notification_category(
                 actor(subscriber),
                 "channel_live",
                 page: 2,
                 page_size: 1
               )

      assert length(page.entries) == 1
      assert page.page_number == 2

      assert Notifications.show_unread_notification_category(
               actor(subscriber),
               "unknown",
               @pagination
             ) ==
               {:error, :not_found}
    end
  end

  describe "event services" do
    test "every broadcast is duplicate-safe and every clear is idempotent" do
      subscriber = confirmed_user_fixture()
      author = confirmed_user_fixture()

      for event <- event_cases(subscriber, author) do
        assert {:ok, 1} = event.broadcast.(), "first #{event.category} broadcast"
        assert {:ok, 1} = event.broadcast.(), "duplicate #{event.category} broadcast"
        assert Repo.aggregate(event.schema, :count) == 1
        assert {:ok, 1} = event.clear.()
        assert {:ok, 0} = event.clear.()
      end
    end

    test "every broadcast joins and rolls back with an ambient transaction" do
      subscriber = confirmed_user_fixture()
      author = confirmed_user_fixture()

      for event <- event_cases(subscriber, author) do
        assert Repo.transact(fn ->
                 assert {:ok, 1} = event.broadcast.()
                 {:error, :forced_rollback}
               end) == {:error, :forced_rollback}

        assert Repo.aggregate(event.schema, :count) == 0
      end
    end

    test "forum authors do not notify themselves" do
      author = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, author)
      {:ok, _subscription} = Philomena.Forums.create_subscription(forum, author)

      assert Notifications.broadcast_forum_topic(author, topic) == {:ok, 0}
      assert Repo.aggregate(ForumTopicNotification, :count) == 0
    end

    test "anonymous clear paths are successful no-ops" do
      channel = channel_fixture()

      assert Notifications.clear_channel_live(channel, nil) == {:ok, 0}
    end
  end
end
