defmodule Philomena.BackgroundJobsTest do
  use Philomena.DataCase, async: false
  use Patch

  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Comments
  alias Philomena.Comments.Comment
  alias Philomena.Filters
  alias Philomena.Filters.Filter
  alias Philomena.Galleries
  alias Philomena.Galleries.Gallery
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.Images.Thumbnailer
  alias Philomena.Multi
  alias Philomena.Posts
  alias Philomena.Posts.Post
  alias Philomena.Reports
  alias Philomena.Reports.Report
  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChange
  alias Philomena.Tags
  alias Philomena.Tags.Tag
  alias Philomena.Topics.Topic
  alias Philomena.Users
  alias Philomena.Users.User

  defp assert_enqueued(queue, worker, arguments, count \\ 1) do
    call = {:enqueue, [Exq, queue, worker, arguments]}
    assert Enum.count(history(Exq), &(&1 == call)) == count
  end

  describe "search indexing jobs" do
    test "comments enqueue the selected id column and values" do
      comment = %Comment{id: 11}
      image = %Image{id: 12}
      spy(Exq)

      assert Comments.reindex_comment(comment) == comment
      assert Comments.reindex_comments_on_image(image) == image
      assert Comments.reindex_comments_on_images([12, 13]) == [12, 13]

      assert_enqueued("indexing", Philomena.IndexWorker, ["Comments", "id", [11]])
      assert_enqueued("indexing", Philomena.IndexWorker, ["Comments", "image_id", [12]])
      assert_enqueued("indexing", Philomena.IndexWorker, ["Comments", "image_id", [12, 13]])
    end

    test "filters enqueue their id" do
      filter = %Filter{id: 21}
      spy(Exq)

      assert Filters.reindex_filter(filter) == filter

      assert_enqueued("indexing", Philomena.IndexWorker, ["Filters", "id", [21]])
    end

    test "galleries enqueue one or many ids and skip an empty batch" do
      gallery = %Gallery{id: 31}
      spy(Exq)

      assert Galleries.reindex_gallery(gallery) == gallery
      assert Galleries.reindex_galleries([31, 32]) == [31, 32]
      assert Galleries.reindex_galleries([]) == []

      assert_enqueued("indexing", Philomena.IndexWorker, ["Galleries", "id", [31]])
      assert_enqueued("indexing", Philomena.IndexWorker, ["Galleries", "id", [31, 32]])
    end

    test "images enqueue one or many ids" do
      image = %Image{id: 41}
      spy(Exq)

      assert Images.reindex_image(image) == image
      assert Images.reindex_images([41, 42]) == [41, 42]

      assert_enqueued("indexing", Philomena.IndexWorker, ["Images", "id", [41]])
      assert_enqueued("indexing", Philomena.IndexWorker, ["Images", "id", [41, 42]])
    end

    test "posts enqueue a post id or a topic id" do
      post = %Post{id: 51}
      topic = %Topic{id: 52}
      spy(Exq)

      assert Posts.reindex_post(post) == post
      assert Posts.reindex_posts_in_topic(topic) == :ok

      assert_enqueued("indexing", Philomena.IndexWorker, ["Posts", "id", [51]])
      assert_enqueued("indexing", Philomena.IndexWorker, ["Posts", "topic_id", [52]])
    end

    test "persisted tag changes enqueue their generated id after commit" do
      user = confirmed_user_fixture()
      tags = "safe, background base one, background base two"
      image = image_fixture(tags: tags)
      reset_tag_change_limits(attribution(user))
      spy(Exq)

      assert {:ok, _image} =
               Images.update_image_tags(actor(user), image.id, %{
                 "old_tag_input" => tags,
                 "tag_input" => "#{tags}, background added tag"
               })

      tag_change = Repo.get_by!(TagChange, image_id: image.id)

      assert_enqueued("indexing", Philomena.IndexWorker, [
        "TagChanges",
        "id",
        [tag_change.id]
      ])
    end

    test "image uploader and anonymity changes enqueue the image's tag changes" do
      moderator = moderator_user_fixture()
      image = image_fixture()
      spy(Exq)

      assert {:ok, _image} = Images.update_anonymous(actor(moderator), image.id, true)

      assert {:ok, _image} =
               Images.update_image_uploader(actor(moderator), image.id, %{
                 "username" => moderator.name
               })

      assert_enqueued(
        "indexing",
        Philomena.IndexWorker,
        ["TagChanges", "image_id", [image.id]],
        2
      )
    end

    test "tags enqueue a batch of ids" do
      tag = %Tag{id: 71}
      other_tag = %Tag{id: 72}
      spy(Exq)

      assert Tags.reindex_tags([tag, other_tag]) == [tag, other_tag]

      assert_enqueued("indexing", Philomena.IndexWorker, ["Tags", "id", [71, 72]])
    end

    test "users enqueue their id" do
      user = %User{id: 81}
      spy(Exq)

      assert Users.reindex_user(user) == user

      assert_enqueued("indexing", Philomena.IndexWorker, ["Users", "id", [81]])
    end
  end

  describe "image processing jobs" do
    test "repairs use the image queue for still images and the video queue for WebM" do
      moderator = moderator_user_fixture()
      image = image_fixture()
      video = image_fixture(image_mime_type: "video/webm", image_format: "webm")
      image_id = image.id
      video_id = video.id
      spy(Exq)

      assert {:ok, repaired_image} = Images.create_image_repair(actor(moderator), image.id)
      assert {:ok, repaired_video} = Images.create_image_repair(actor(moderator), video.id)
      assert repaired_image.id == image.id
      assert repaired_video.id == video.id

      assert_enqueued("images", Philomena.ThumbnailWorker, [image_id])
      assert_enqueued("videos", Philomena.ThumbnailWorker, [video_id])
    end

    test "purges every visible and hidden thumbnail path" do
      moderator = moderator_user_fixture()
      hidden_key = "hidden-key"
      image = image_fixture(hidden_image_key: hidden_key)

      expected_files =
        Thumbnailer.thumbnail_urls(image, hidden_key) ++ Thumbnailer.thumbnail_urls(image, nil)

      spy(Exq)

      assert {:ok, _image} = Images.create_image_repair(actor(moderator), image.id)

      assert_enqueued("indexing", Philomena.ImagePurgeWorker, [expected_files])
    end
  end

  describe "tag maintenance jobs" do
    test "delete, alias, unalias, and image reindex actions enqueue exact ids" do
      admin = admin_user_fixture()
      target = tag_fixture(name: "background target")
      delete_tag = tag_fixture(name: "background delete")
      alias_tag = tag_fixture(name: "background alias")
      target_id = target.id
      delete_tag_id = delete_tag.id
      alias_tag_id = alias_tag.id
      spy(Exq)

      assert {:ok, %Tag{id: ^delete_tag_id}} = Tags.delete_tag(actor(admin), delete_tag.slug)

      assert {:ok, aliased} =
               Tags.update_tag_alias(actor(admin), alias_tag.slug, %{"target_tag" => target.name})

      finalized_alias = Repo.get!(Tag, alias_tag_id)
      Repo.update!(Ecto.Changeset.change(finalized_alias, aliased_tag_id: target_id))
      assert {:ok, %Tag{id: ^alias_tag_id}} = Tags.delete_tag_alias(actor(admin), aliased.slug)

      assert {:ok, %Tag{id: ^target_id}} =
               Tags.create_tag_reindex(actor(admin), target.slug)

      assert_enqueued("indexing", Philomena.TagDeleteWorker, [delete_tag_id])
      assert_enqueued("indexing", Philomena.TagAliasWorker, [alias_tag_id, target_id])
      assert_enqueued("indexing", Philomena.TagReindexWorker, [target_id], 2)
      assert_enqueued("indexing", Philomena.IndexWorker, ["Tags", "id", [target_id]])
    end
  end

  describe "user maintenance jobs" do
    test "vote, downvote, PII, rename, and erasure workflows enqueue exact arguments" do
      admin = admin_user_fixture()
      target = user_fixture(name: "background target")
      target_id = target.id
      spy(Exq)

      assert {:ok, %User{id: ^target_id}} = Users.delete_user_downvotes(actor(admin), target.slug)
      assert {:ok, %User{id: ^target_id}} = Users.delete_user_votes(actor(admin), target.slug)
      assert {:ok, %User{id: ^target_id}} = Users.create_user_wipe(actor(admin), target.slug)

      assert_enqueued("indexing", Philomena.UserUnvoteWorker, [target_id, false])
      assert_enqueued("indexing", Philomena.UserUnvoteWorker, [target_id, true])
      assert_enqueued("indexing", Philomena.UserWipeWorker, [target_id])

      old_name = admin.name
      assert {:ok, renamed_admin} = Users.update_name(actor(admin), %{"name" => "renamed admin"})
      new_name = renamed_admin.name
      admin_id = renamed_admin.id

      assert_enqueued("indexing", Philomena.UserRenameWorker, [old_name, new_name])

      assert {:ok, erased} = Users.create_user_erase(actor(renamed_admin), target.slug)
      erased_id = erased.id

      assert_enqueued("indexing", Philomena.UserEraseWorker, [target_id, admin_id])
      assert_enqueued("indexing", Philomena.IndexWorker, ["Users", "id", [erased_id]])
    end
  end

  describe "tag-change revert jobs" do
    test "full reverts carry each target and the moderator attribution" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()
      moderator_actor = actor(moderator)
      target_id = target.id

      attributes = %{
        ip: to_string(moderator_actor.ip),
        fingerprint: moderator_actor.fingerprint,
        user_id: moderator.id,
        batch_size: 100
      }

      spy(Exq)

      assert {:ok, %User{id: ^target_id}} =
               TagChanges.create_user_tag_change_revert(moderator_actor, target.slug)

      assert {:ok, "203.0.113.9"} =
               TagChanges.create_ip_tag_change_revert(moderator_actor, "203.0.113.9")

      assert {:ok, "c1774"} =
               TagChanges.create_fingerprint_tag_change_revert(moderator_actor, "c1774")

      assert_enqueued("indexing", Philomena.TagChangeRevertWorker, [
        %{user_id: target_id, attributes: attributes}
      ])

      assert_enqueued("indexing", Philomena.TagChangeRevertWorker, [
        %{ip: "203.0.113.9", attributes: attributes}
      ])

      assert_enqueued("indexing", Philomena.TagChangeRevertWorker, [
        %{fingerprint: "c1774", attributes: attributes}
      ])
    end
  end

  describe "report jobs" do
    test "closing a report enqueues its id after commit" do
      image = image_fixture()
      reporter = confirmed_user_fixture()
      moderator = moderator_user_fixture()
      report = Philomena.ReportsFixtures.report_fixture(reporter, %{}, image_id: image.id)
      report_id = report.id
      spy(Exq)

      assert {:ok, %Report{id: ^report_id}} =
               Reports.create_report_close(actor(moderator), report_id)

      assert_enqueued("indexing", Philomena.IndexWorker, ["Reports", "id", [report_id]])
    end

    test "bulk report closure enqueues the returned id list" do
      image = image_fixture()
      reporter = confirmed_user_fixture()
      moderator = moderator_user_fixture()
      report = Philomena.ReportsFixtures.report_fixture(reporter, %{}, image_id: image.id)
      spy(Exq)

      assert {:ok, %{reports: {1, [report_id]}}} =
               Multi.new()
               |> Reports.put_close_reports(:reports, moderator, image_id: image.id)
               |> Multi.transact()

      assert report_id == report.id
      assert_enqueued("indexing", Philomena.IndexWorker, ["Reports", "id", [report_id]])
    end
  end
end
