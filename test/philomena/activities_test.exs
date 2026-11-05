defmodule Philomena.ActivitiesTest do
  @moduledoc """
  Context-level tests for `Philomena.Activities.load_front_page/4`, which
  assembles the homepage strips for a viewer.

  The recent, top-scoring, comment, and watched strips run against the real
  OpenSearch indexes; the featured image, streams, and topics load from
  Postgres.
  """

  use Philomena.DataCase, async: false

  @moduletag :search

  import Philomena.AttributionFixtures
  import Philomena.ChannelsFixtures
  import Philomena.CommentsFixtures
  import Philomena.ForumsFixtures
  import Philomena.ImagesFixtures
  import Philomena.TagsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Activities
  alias Philomena.Activities.FrontPage
  alias Philomena.Channels.Channel
  alias Philomena.Comments.Comment
  alias Philomena.Filters.Filter
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.Images.Search.Scope
  alias Philomena.Tags
  alias Philomena.Topics
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  setup do
    Search.clear_index!(Image)
    Search.clear_index!(Comment)
    :ok
  end

  # The compiled filter body the web layer produces for a viewer with no active
  # filter: an empty tag_ids exclusion plus a pair of match_none clauses, so it
  # excludes nothing.
  defp default_filter do
    %{
      bool: %{
        should: [
          %{terms: %{tag_ids: []}},
          %{bool: %{should: [%{match_none: %{}}, %{match_none: %{}}]}}
        ]
      }
    }
  end

  defp scope do
    Scope.new(default_filter(), %{page_number: 1, page_size: 25})
  end

  # The %Filter{} the web layer passes as the comment-strip filter; only its
  # hidden_tag_ids are read.
  defp filter, do: %Filter{hidden_tag_ids: []}

  defp seed_rand(seed), do: :rand.seed(:exsss, seed)

  defp hours_ago(hours) do
    DateTime.utc_now()
    |> DateTime.add(-hours * 3600, :second)
    |> DateTime.truncate(:second)
  end

  # A live channel needs a fetch time to appear at all; the front page filters
  # on last_fetched_at. create_channel casts only the type and short name, so
  # the fetch time and nsfw flag are set directly on the row.
  defp live_channel(fields) do
    channel_fixture(%{})
    |> Ecto.Changeset.change(Enum.into(fields, %{last_fetched_at: hours_ago(1)}))
    |> Repo.update!()
  end

  describe "show_activity/3 for an anonymous scope" do
    test "empty search and database sections stay empty" do
      assert {:ok, front} = Activities.show_activity(actor(), scope(), filter(), false)

      assert front.images.entries == []
      assert front.top_scoring.entries == []
      assert front.comments.entries == []
      assert front.watched == nil
      assert front.featured_image == nil
      assert Enum.count(front.streams) == 0
      assert Enum.count(front.topics) == 0
      assert front.interactions == []
    end

    test "returns a FrontPage struct with every key populated" do
      image = image_fixture(created_at: hours_ago(1))
      comment = comment_fixture(image, confirmed_user_fixture())
      topic = topic_fixture(forum_fixture())

      SearchHelpers.reindex_all!(Image)
      SearchHelpers.reindex_all!(Comment)

      assert {:ok, front} = Activities.show_activity(actor(), scope(), filter(), false)

      assert %FrontPage{} = front

      assert %Scrivener.Page{} = front.images
      assert image.id in Enum.map(front.images.entries, & &1.id)

      assert %Scrivener.Page{} = front.top_scoring

      assert %Scrivener.Page{} = front.comments
      assert comment.id in Enum.map(front.comments.entries, & &1.id)

      # Anonymous viewers have no watched strip.
      assert front.watched == nil

      # No feature and no channels on a fresh site.
      assert front.featured_image == nil
      assert Enum.count(front.streams) == 0

      assert Enum.any?(front.topics, &(&1.id == topic.id))
      assert is_list(front.interactions)
    end

    test "the trending strip ranks recent images by score, not upload time" do
      liked = image_fixture(first_seen_at: hours_ago(2))
      newer = image_fixture(first_seen_at: hours_ago(1))

      liked
      |> Ecto.Changeset.change(upvotes_count: 10, score: 10)
      |> Repo.update!()

      SearchHelpers.reindex_all!(Image)

      # The strip shows a random one of its first six pages; seed the process
      # so it lands on the first page, where both images are.
      seed = Enum.find(1..1000, fn seed -> seed_rand(seed) && :rand.uniform(6) == 1 end)
      seed_rand(seed)

      assert {:ok, front} = Activities.show_activity(actor(), scope(), filter(), false)

      assert Enum.map(front.top_scoring.entries, & &1.id) == [liked.id, newer.id]
    end

    test "the recent listing preloads each image's tags" do
      image = image_fixture(created_at: hours_ago(1))
      SearchHelpers.reindex_all!(Image)

      assert {:ok, front} = Activities.show_activity(actor(), scope(), filter(), false)

      entry = Enum.find(front.images.entries, &(&1.id == image.id))
      assert Ecto.assoc_loaded?(entry.tags)
    end

    test "the featured image is set when an image feature exists" do
      image = image_fixture(created_at: hours_ago(1))
      {:ok, _feature} = Images.create_image_feature(actor(moderator_user_fixture()), image.id)

      SearchHelpers.reindex_all!(Image)

      assert {:ok, front} = Activities.show_activity(actor(), scope(), filter(), false)

      assert front.featured_image.id == image.id
    end
  end

  describe "show_activity/3 for a signed-in scope" do
    test "the watched strip is a page rather than nil" do
      user = confirmed_user_fixture()

      assert {:ok, front} =
               Activities.show_activity(actor(user), scope(), filter(), false)

      assert %Scrivener.Page{} = front.watched
      assert is_list(front.watched.entries)
    end

    test "the actor's watched tags are authoritative over the search scope" do
      user = confirmed_user_fixture()
      tag = tag_fixture()
      image = image_fixture(tags: tag.name)
      {:ok, watching_user} = Tags.create_tag_watch(actor(user), tag.slug)
      SearchHelpers.reindex_all!(Image)

      assert {:ok, front} =
               Activities.show_activity(actor(watching_user), scope(), filter(), false)

      assert image.id in Enum.map(front.watched.entries, & &1.id)
    end

    test "image strips carry the actor's interactions" do
      user = confirmed_user_fixture()
      image = image_fixture(created_at: hours_ago(1))
      {:ok, _image} = Images.create_image_fave(actor(user), image.id)
      SearchHelpers.reindex_all!(Image)

      assert {:ok, front} =
               Activities.show_activity(actor(user), scope(), filter(), false)

      assert Enum.any?(front.interactions, fn interaction ->
               interaction.image_id == image.id and interaction.interaction_type == "faved"
             end)
    end

    test "a personal hide controls the featured image unless hidden results are requested" do
      user = confirmed_user_fixture()
      image = image_fixture(created_at: hours_ago(1))
      {:ok, _feature} = Images.create_image_feature(actor(moderator_user_fixture()), image.id)
      {:ok, _image} = Images.create_image_user_hide(actor(user), image.id)

      assert {:ok, hidden_front} =
               Activities.show_activity(actor(user), scope(), filter(), false)

      assert hidden_front.featured_image == nil

      include_hidden_scope = %{scope() | hidden: true}

      assert {:ok, visible_front} =
               Activities.show_activity(actor(user), include_hidden_scope, filter(), false)

      assert visible_front.featured_image.id == image.id
    end
  end

  describe "show_activity/3 topic visibility" do
    test "hidden topics are never shown in front-page topics, but staff topics can be shown to staff" do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      hidden = topic_fixture(forum)

      {:ok, {_forum, hidden}} =
        Topics.create_topic_hide(actor(moderator), forum.short_name, hidden.slug, %{
          "deletion_reason" => "Rule #0"
        })

      staff_topic = topic_fixture(forum_fixture(%{access_level: "staff"}))

      assert {:ok, public_front} =
               Activities.show_activity(actor(), scope(), filter(), false)

      public_ids = Enum.map(public_front.topics, & &1.id)
      refute hidden.id in public_ids
      refute staff_topic.id in public_ids

      assert {:ok, moderator_front} =
               Activities.show_activity(actor(moderator), scope(), filter(), false)

      moderator_ids = Enum.map(moderator_front.topics, & &1.id)
      refute hidden.id in moderator_ids
      assert staff_topic.id in moderator_ids
    end
  end

  describe "show_activity/3 stream strip" do
    test "a channel with a fetch time appears in the streams" do
      channel = live_channel(%{})

      assert {:ok, front} = Activities.show_activity(actor(), scope(), filter(), false)

      assert Enum.any?(front.streams, &(&1.id == channel.id))
    end

    test "a channel without a fetch time never appears" do
      channel = channel_fixture(%{})
      assert channel.last_fetched_at == nil

      assert {:ok, front} = Activities.show_activity(actor(), scope(), filter(), false)

      refute Enum.any?(front.streams, &(&1.id == channel.id))
    end

    test "an nsfw channel is hidden when nsfw channels are off" do
      channel = live_channel(%{nsfw: true})

      assert {:ok, front} = Activities.show_activity(actor(), scope(), filter(), false)

      refute Enum.any?(front.streams, &(&1.id == channel.id))
    end

    test "an nsfw channel appears when nsfw channels are on" do
      channel = live_channel(%{nsfw: true})

      assert {:ok, front} = Activities.show_activity(actor(), scope(), filter(), true)

      assert Enum.any?(front.streams, &(&1.id == channel.id))
    end

    test "a safe channel appears regardless of the nsfw switch" do
      channel = live_channel(%{nsfw: false})

      assert %Channel{} = channel
      assert {:ok, front} = Activities.show_activity(actor(), scope(), filter(), false)

      assert Enum.any?(front.streams, &(&1.id == channel.id))
    end
  end
end
