defmodule Philomena.FixturesTest do
  @moduledoc """
  Smoke tests for the fixture modules. Each test proves the fixture inserts
  a row in the expected shape; controller tests build on top of these.
  """

  use Philomena.DataCase, async: true

  import Philomena.UsersFixtures

  alias Philomena.BadgesFixtures
  alias Philomena.ChannelsFixtures
  alias Philomena.CommentsFixtures
  alias Philomena.ConversationsFixtures
  alias Philomena.ForumsFixtures
  alias Philomena.GalleriesFixtures
  alias Philomena.ImagesFixtures
  alias Philomena.PostsFixtures
  alias Philomena.ReportsFixtures
  alias Philomena.RulesFixtures
  alias Philomena.TagsFixtures
  alias Philomena.TopicsFixtures

  describe "tag_fixture/1" do
    test "creates a tag with derived slug" do
      tag = TagsFixtures.tag_fixture()
      assert tag.slug =~ "test+tag"
      assert tag.category == nil
    end

    test "applies category and namespace" do
      tag = TagsFixtures.tag_fixture(%{name: "spike", category: "character"})
      assert tag.category == "character"

      artist = TagsFixtures.tag_fixture(%{name: "artist:testartist#{System.unique_integer()}"})
      assert artist.namespace == "artist"
      assert artist.category == "origin"
    end
  end

  describe "topic_fixture/3 and post_fixture/3" do
    test "creates a topic with first post, then a reply" do
      forum = ForumsFixtures.forum_fixture()
      user = confirmed_user_fixture()

      topic = TopicsFixtures.topic_fixture(forum, user)
      assert topic.forum_id == forum.id
      assert topic.user_id == user.id
      assert [first_post] = topic.posts
      assert first_post.topic_position == 0

      reply = PostsFixtures.post_fixture(topic, user, %{"body" => "A reply"})
      assert reply.topic_id == topic.id
      assert reply.topic_position == 1
      assert reply.body == "A reply"
    end

    test "creates an anonymously displayed topic" do
      forum = ForumsFixtures.forum_fixture()

      topic = TopicsFixtures.topic_fixture(forum)
      assert topic.user_id
      assert topic.anonymous
    end
  end

  describe "comment_fixture/3" do
    test "creates a comment and bumps the image count" do
      image = ImagesFixtures.image_fixture()
      user = confirmed_user_fixture()

      comment = CommentsFixtures.comment_fixture(image, user)
      assert comment.image_id == image.id
      assert comment.user_id == user.id
      assert comment.approved

      assert Repo.reload!(image).comments_count == 1
    end
  end

  describe "gallery_fixture/2" do
    test "creates a gallery with a generated thumbnail image" do
      user = confirmed_user_fixture()

      gallery = GalleriesFixtures.gallery_fixture(user)
      assert gallery.user_id == user.id
      assert gallery.thumbnail_id
    end
  end

  describe "conversation_fixture/3 and message_fixture/3" do
    test "creates a conversation with one message, then a reply" do
      from = confirmed_user_fixture()
      to = confirmed_user_fixture()

      conversation = ConversationsFixtures.conversation_fixture(from, to)
      assert conversation.from_id == from.id
      assert conversation.to_id == to.id
      assert [message] = conversation.messages
      assert message.approved

      reply = ConversationsFixtures.message_fixture(conversation, to)
      assert reply.conversation_id == conversation.id
      assert reply.from_id == to.id
    end
  end

  describe "rule_fixture/1 and report_fixture/3" do
    test "creates a rule" do
      rule = RulesFixtures.rule_fixture()
      assert rule.name =~ "Test Rule"
      refute rule.internal
    end

    test "creates an image report with a generated rule" do
      image = ImagesFixtures.image_fixture()
      user = confirmed_user_fixture()

      report = ReportsFixtures.report_fixture(user, image_id: image.id)
      assert report.image_id == image.id
      assert report.user_id == user.id
      assert report.open
      assert report.rule_id
    end

    test "creates an anonymous report" do
      image = ImagesFixtures.image_fixture()

      report = ReportsFixtures.report_fixture(image_id: image.id)
      assert report.user_id == nil
    end
  end

  describe "channel_fixture/1" do
    test "creates a channel" do
      channel = ChannelsFixtures.channel_fixture()
      assert channel.type == "PicartoChannel"
      assert channel.short_name =~ "test_channel_"
    end
  end

  describe "badge_fixture/1 and badge_award_fixture/4" do
    test "creates a badge and awards it" do
      admin = admin_user_fixture()
      user = confirmed_user_fixture()

      badge = BadgesFixtures.badge_fixture()
      assert badge.image == "test.svg"

      award = BadgesFixtures.badge_award_fixture(admin, user, badge)
      assert award.badge_id == badge.id
      assert award.user_id == user.id
      assert award.awarded_by_id == admin.id
      assert award.awarded_on
    end
  end
end
