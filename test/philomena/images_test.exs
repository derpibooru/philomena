defmodule Philomena.ImagesTest do
  # async: false - successful image uploads spawn an upload process
  # (Images.async_upload/2) that hits the Repo; it is only allowed on the
  # sandbox connection in shared mode, which is enabled for sync tests.
  use Philomena.DataCase, async: false
  use Patch

  import Ecto.Query

  alias Phoenix.Socket.Broadcast
  alias Philomena.Multi
  alias Philomena.ImageFaves
  alias Philomena.ImageFaves.ImageFave
  alias Philomena.ImageFeatures.ImageFeature
  alias Philomena.ImageHides
  alias Philomena.ImageHides.ImageHide
  alias Philomena.Comments
  alias Philomena.Galleries.Interaction
  alias Philomena.Images
  alias Philomena.ImageVotes
  alias Philomena.ImageVotes.ImageVote
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Notifications
  alias Philomena.Notifications.ImageCommentNotification
  alias Philomena.Notifications.ImageMergeNotification
  alias Philomena.Reports.Report
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.TagChanges.Limits
  alias Philomena.TagChanges.TagChange
  alias Philomena.Images.Image
  alias Philomena.Images.ImagePage
  alias Philomena.Images.Search.Scope
  alias Philomena.Tags.Tag
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers
  alias PhilomenaWeb.Endpoint

  import Philomena.AsyncUpload
  import Philomena.GalleriesFixtures
  import Philomena.FiltersFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures
  import Philomena.AttributionFixtures
  import Philomena.CommentsFixtures
  import Philomena.RulesFixtures
  import Philomena.TagsFixtures

  # A truthy ban value in the shape production passes (the result of
  # Philomena.Bans.find/3); only its presence matters to verify_write_access.
  @ban %{
    reason: "Rule #0",
    valid_until: ~U[3000-01-01 00:00:00Z],
    generated_ban_id: "U123456",
    type: "User"
  }

  @approval_pagination %{page_number: 1, page_size: 25}

  import Philomena.SourceChangesFixtures

  defp image_tag_names(image) do
    Image
    |> Repo.get(image.id)
    |> Repo.preload(:tags)
    |> Map.fetch!(:tags)
    |> Enum.map(& &1.name)
  end

  defp comment_notification?(image, user) do
    Repo.exists?(
      from n in ImageCommentNotification,
        where: n.image_id == ^image.id and n.user_id == ^user.id
    )
  end

  defp merge_notification?(image, user) do
    Repo.exists?(
      from n in ImageMergeNotification,
        where: n.target_id == ^image.id and n.user_id == ^user.id
    )
  end

  # Arranges a real unread image comment notification for `user`: subscribe the
  # user to the image, then have another user comment so a notification lands.
  defp arrange_comment_notification(image, user) do
    author = confirmed_user_fixture()
    {:ok, _} = Images.create_subscription(image, user)
    comment = comment_fixture(image, author)
    {:ok, _} = Notifications.broadcast_image_comment(author, image, comment)
    :ok
  end

  # Arranges a real unread image merge notification for `user`: subscribe the
  # user to the source image, then broadcast its merge into the target.
  defp arrange_merge_notification(image, user) do
    source = image_fixture()
    {:ok, _} = Images.create_subscription(source, user)
    {:ok, _} = Notifications.broadcast_image_merge(image, source)
    :ok
  end

  defp only_moderation_log!, do: Repo.one!(ModerationLog)

  defp moderation_log_count, do: Repo.aggregate(ModerationLog, :count)

  defp source_change_count(image) do
    Repo.aggregate(from(s in SourceChange, where: s.image_id == ^image.id), :count)
  end

  defp fave!(image, user) do
    {:ok, _} =
      Multi.new()
      |> ImageFaves.put_fave_for_loaded_image(image, user)
      |> Multi.transact()
  end

  defp vote!(image, user, up) do
    {:ok, _} =
      Multi.new()
      |> ImageVotes.put_vote_for_loaded_image(image, user, up)
      |> Multi.transact()
  end

  defp hide!(image, user) do
    {:ok, _} =
      Multi.new()
      |> ImageHides.put_hide_for_loaded_image(image, user)
      |> Multi.transact()
  end

  defp has_vote?(image, user) do
    Repo.exists?(from v in ImageVote, where: v.image_id == ^image.id and v.user_id == ^user.id)
  end

  defp image_hide_count(image, user) do
    Repo.aggregate(
      from(h in ImageHide, where: h.image_id == ^image.id and h.user_id == ^user.id),
      :count
    )
  end

  defp fave_count(image, user) do
    Repo.aggregate(
      from(f in ImageFave, where: f.image_id == ^image.id and f.user_id == ^user.id),
      :count
    )
  end

  defp vote_row(image, user) do
    Repo.get_by(ImageVote, image_id: image.id, user_id: user.id)
  end

  defp force_filter(user, attrs) do
    filter =
      system_filter_fixture()
      |> Ecto.Changeset.change(attrs)
      |> Repo.update!()

    user =
      user
      |> Ecto.Changeset.change(forced_filter_id: filter.id)
      |> Repo.update!()

    {user, filter}
  end

  defp source_change_row_count(image) do
    Repo.aggregate(from(s in SourceChange, where: s.image_id == ^image.id), :count)
  end

  defp source_urls(image) do
    image
    |> Repo.preload(:sources, force: true)
    |> Map.fetch!(:sources)
    |> Enum.map(& &1.source)
  end

  # Controller-shaped attrs adding a single source with no prior sources.
  defp add_source_attrs(url) do
    %{"old_sources" => %{}, "sources" => %{"0" => %{"source" => url}}}
  end

  describe "list_images_by_ids/1" do
    test "loads matching images with rich-text representation associations" do
      image = image_fixture(tags: "safe", sources: ["https://example.com/source"])

      assert [loaded] = Images.list_images_by_ids([image.id, 2_147_483_647])
      assert loaded.id == image.id
      assert Ecto.assoc_loaded?(loaded.sources)
      assert Ecto.assoc_loaded?(loaded.tags)
      assert Enum.all?(loaded.tags, &Ecto.assoc_loaded?(&1.aliases))
    end
  end

  defp tag_names(image) do
    image
    |> Repo.preload(:tags, force: true)
    |> Map.fetch!(:tags)
    |> Enum.map(& &1.name)
    |> Enum.sort()
  end

  defp image_reindex(image),
    do: [Exq, "indexing", Philomena.IndexWorker, ["Images", "id", [image.id]]]

  defp tag_attrs(old_tag_input, tag_input) do
    %{"old_tag_input" => old_tag_input, "tag_input" => tag_input}
  end

  # Controller-shaped attrs adding `count` distinct sources.
  defp many_source_attrs(count) do
    sources =
      Map.new(0..(count - 1), fn i ->
        {to_string(i), %{"source" => "https://example.com/#{i}"}}
      end)

    %{"old_sources" => %{}, "sources" => sources}
  end

  defp hidden_image_fixture(reason \\ "Original reason") do
    image = image_fixture()
    moderator = moderator_user_fixture()

    {:ok, hidden} =
      Images.create_image_hide(actor(moderator), image.id, %{"deletion_reason" => reason})

    Repo.delete_all(ModerationLog)

    hidden
  end

  defp feature_row_count(image) do
    Repo.aggregate(from(f in ImageFeature, where: f.image_id == ^image.id), :count)
  end

  defp locked_tag_names(image) do
    image
    |> Repo.reload!()
    |> Repo.preload(:locked_tags)
    |> Map.fetch!(:locked_tags)
    |> Enum.map(& &1.name)
    |> Enum.sort()
  end

  describe "create_image/2 duplicate detection" do
    # image_changeset's prepare_changes rejects a new upload whose
    # image_orig_sha512_hash already belongs to another image. On INSERT the
    # changeset's data.id is nil, so the self-exclusion added to fix the file
    # replacement bug never applies here - a genuine duplicate is still a
    # duplicate. create_image surfaces the changeset error as the raw Multi
    # failure tuple {:error, :image, changeset, changes}.
    test "rejects a new upload whose file duplicates an existing image's hash" do
      existing = image_fixture(image_orig_sha512_hash: png_upload_sha512())
      user = user_fixture()

      attrs = %{"tag_input" => "safe, solo, mare"}
      upload = media_png_upload()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Images.create_image(actor(user), attrs, upload)

      assert "has already been uploaded: it's image #{existing.id}" in errors_on(changeset).image
    end
  end

  describe "create_image_hide/3 gallery cleanup" do
    # Hiding (deleting) an image removes it from every gallery containing it.
    # The gallery search document serializes image_count and image_ids, so the
    # transaction must surface the affected gallery ids for reindexing - the
    # galleries step returns them, and process_after_hide queues the reindex.
    test "removes the image from galleries and returns the affected gallery ids" do
      moderator = moderator_user_fixture()
      image = image_fixture()
      gallery = gallery_fixture(user_fixture())
      gallery_image_fixture(gallery, image)

      assert {:ok, _hidden} =
               Images.create_image_hide(actor(moderator), image.id, %{
                 "deletion_reason" => "Rule violation"
               })

      assert Repo.reload!(gallery).image_count == 0
      refute Repo.get_by(Interaction, gallery_id: gallery.id)
    end

    test "returns no gallery ids when the image is in no gallery" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, _hidden} =
               Images.create_image_hide(actor(moderator), image.id, %{
                 "deletion_reason" => "Rule violation"
               })
    end
  end

  describe "merge_image/4 gallery migration" do
    test "replaces the source image with the target image, retaining position" do
      moderator = user_fixture()
      source = image_fixture()
      target = image_fixture()
      filler = image_fixture()
      gallery = gallery_fixture(user_fixture())
      gallery_image_fixture(gallery, filler)
      gallery_image_fixture(gallery, source)

      assert {:ok, _result} =
               Multi.new()
               |> Images.put_merge_image(source, target, moderator)
               |> Multi.transact()

      # The source image's interaction was repointed in place.
      assert %{position: 1} =
               Repo.get_by(Interaction, gallery_id: gallery.id, image_id: target.id)

      refute Repo.get_by(Interaction, gallery_id: gallery.id, image_id: source.id)
      assert Repo.reload!(gallery).image_count == 2
    end

    test "only removes the source image from a gallery already containing the target" do
      moderator = user_fixture()
      source = image_fixture()
      target = image_fixture()
      gallery = gallery_fixture(user_fixture())
      gallery_image_fixture(gallery, source)
      gallery_image_fixture(gallery, target)

      assert {:ok, _result} =
               Multi.new()
               |> Images.put_merge_image(source, target, moderator)
               |> Multi.transact()

      # The target keeps its own interaction; the source's is simply deleted.
      assert [%{image_id: target_id, position: 1}] =
               Repo.all(where(Interaction, gallery_id: ^gallery.id))

      assert target_id == target.id
      assert Repo.reload!(gallery).image_count == 1
    end
  end

  describe "merge image notifications" do
    test "notifies only source subscribers and clears on viewing the retained image" do
      moderator = user_fixture()
      source = image_fixture()
      target = image_fixture()
      source_subscriber = confirmed_user_fixture()
      target_subscriber = confirmed_user_fixture()
      shared_subscriber = confirmed_user_fixture()

      for subscriber <- [source_subscriber, shared_subscriber] do
        {:ok, _} = Images.create_subscription(source, subscriber)
      end

      for subscriber <- [target_subscriber, shared_subscriber] do
        {:ok, _} = Images.create_subscription(target, subscriber)
      end

      assert {:ok, _} =
               Multi.new()
               |> Images.put_merge_image(source, target, moderator)
               |> Multi.transact()

      notifications = Repo.all(ImageMergeNotification)

      assert Enum.sort(Enum.map(notifications, & &1.user_id)) ==
               Enum.sort([source_subscriber.id, shared_subscriber.id])

      assert Enum.all?(notifications, fn notification ->
               notification.source_id == source.id and notification.target_id == target.id
             end)

      assert {:ok, _} = Images.create_image_read(actor(source_subscriber), target.id)
      refute merge_notification?(target, source_subscriber)
      assert merge_notification?(target, shared_subscriber)
    end
  end

  describe "merge_image/4 target updates" do
    test "combines the source image's sources into the target image" do
      moderator = user_fixture()
      source = image_fixture(sources: ["https://example.com/source"])
      target = image_fixture(sources: ["https://example.com/target"])

      assert {:ok, _result} =
               Multi.new()
               |> Images.put_merge_image(source, target, moderator)
               |> Multi.transact()

      assert Enum.sort(source_urls(target)) == [
               "https://example.com/source",
               "https://example.com/target"
             ]
    end

    test "migrates the earliest first_seen_at to the target image" do
      moderator = user_fixture()
      source_first_seen_at = ~U[2020-01-01 00:00:00Z]
      target_first_seen_at = ~U[2021-01-01 00:00:00Z]
      source = image_fixture(first_seen_at: source_first_seen_at)
      target = image_fixture(first_seen_at: target_first_seen_at)

      assert {:ok, _result} =
               Multi.new()
               |> Images.put_merge_image(source, target, moderator)
               |> Multi.transact()

      assert Repo.reload!(target).first_seen_at == source_first_seen_at
    end

    test "adds the source image's comments that are not destroyed to the target's count" do
      moderator = moderator_user_fixture()
      source = image_fixture()
      target = image_fixture()
      comment_fixture(target)
      comment_fixture(source)
      destroyed = comment_fixture(source)

      {:ok, _} =
        Comments.create_comment_hide(actor(moderator), source.id, destroyed.id, %{
          "deletion_reason" => "Spam"
        })

      {:ok, _} = Comments.create_comment_delete(actor(moderator), source.id, destroyed.id)

      assert {:ok, _result} =
               Multi.new()
               |> Images.put_merge_image(source, target, moderator)
               |> Multi.transact()

      assert Repo.reload!(target).comments_count == 2
    end
  end

  describe "update_image_file/3 duplicate detection" do
    # Root cause of the fixed bug: replacing an image's file with a
    # byte-identical copy. The image's own row still holds that file's
    # orig_sha512_hash, so the dedup lookup matches the image against itself;
    # the self-exclusion (other_image.id == changeset.data.id) lets it through
    # instead of raising a spurious "already been uploaded" error. The old code
    # sidestepped this by nulling the hash first; now no nulling is needed.
    test "allows replacing a file with a byte-identical copy of the image's own file" do
      sha = png_upload_sha512()
      image = image_fixture(image_sha512_hash: sha, image_orig_sha512_hash: sha)

      moderator = moderator_user_fixture()

      assert {:ok, updated} =
               Images.update_image_file(actor(moderator), image.id, media_png_upload())

      # The dedup fingerprint is still set - it is overwritten with the (same)
      # new file's hash, never nulled.
      assert updated.image_orig_sha512_hash == sha
    end

    # A file matching a *different* image is still rejected - the self-exclusion
    # only spares the image being updated, not genuine cross-image duplicates.
    # update_image_file returns the changeset error tuple unchanged.
    test "rejects replacing a file with one already uploaded as another image" do
      dup_sha = png_upload_sha512()
      other = image_fixture(image_sha512_hash: dup_sha, image_orig_sha512_hash: dup_sha)
      image = image_fixture()

      moderator = moderator_user_fixture()

      assert {:error, changeset} =
               Images.update_image_file(actor(moderator), image.id, media_png_upload())

      assert "has already been uploaded: it's image #{other.id}" in errors_on(changeset).image
      # The target image keeps its own fingerprint.
      assert Repo.reload!(image).image_orig_sha512_hash == image.image_orig_sha512_hash
    end
  end

  describe "create_image_read/2" do
    test "clears the actor's image comment notification and returns the image" do
      user = confirmed_user_fixture()
      image = image_fixture()
      arrange_comment_notification(image, user)
      assert comment_notification?(image, user)

      assert {:ok, marked} = Images.create_image_read(actor(user), to_string(image.id))
      assert marked.id == image.id
      refute comment_notification?(image, user)
    end

    test "clears the actor's image merge notification and returns the image" do
      user = confirmed_user_fixture()
      image = image_fixture()
      arrange_merge_notification(image, user)
      assert merge_notification?(image, user)

      assert {:ok, marked} = Images.create_image_read(actor(user), to_string(image.id))
      assert marked.id == image.id
      refute merge_notification?(image, user)
    end

    test "clears both comment and merge notifications at once" do
      user = confirmed_user_fixture()
      image = image_fixture()
      arrange_comment_notification(image, user)
      arrange_merge_notification(image, user)
      assert comment_notification?(image, user)
      assert merge_notification?(image, user)

      assert {:ok, marked} = Images.create_image_read(actor(user), to_string(image.id))
      assert marked.id == image.id
      refute comment_notification?(image, user)
      refute merge_notification?(image, user)
    end

    test "clears only the actor's notifications, leaving another user's intact" do
      # clear_image_notification filters on the actor's user_id, so a second
      # subscriber's notification for the same image is untouched.
      user = confirmed_user_fixture()
      other = confirmed_user_fixture()
      image = image_fixture()
      arrange_comment_notification(image, user)
      arrange_comment_notification(image, other)
      assert comment_notification?(image, user)
      assert comment_notification?(image, other)

      assert {:ok, _} = Images.create_image_read(actor(user), to_string(image.id))
      refute comment_notification?(image, user)
      assert comment_notification?(image, other)
    end

    test "succeeds with no notifications to clear" do
      user = confirmed_user_fixture()
      image = image_fixture()
      refute comment_notification?(image, user)
      refute merge_notification?(image, user)

      assert {:ok, marked} = Images.create_image_read(actor(user), to_string(image.id))
      assert marked.id == image.id
    end

    test "accepts an integer id" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert {:ok, marked} = Images.create_image_read(actor(user), image.id)
      assert marked.id == image.id
    end

    test "an unknown well-formed id is not found" do
      user = confirmed_user_fixture()

      assert Images.create_image_read(actor(user), "2147483647") == {:error, :not_found}
    end

    test "a non-castable id is not found" do
      user = confirmed_user_fixture()

      assert Images.create_image_read(actor(user), "not-a-number") == {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      # IntegerId.parse rejects a value the integer column could not hold before
      # the row is ever queried, so it is a plain not found rather than a crash.
      user = confirmed_user_fixture()

      assert Images.create_image_read(actor(user), "99999999999999999999") == {:error, :not_found}
    end
  end

  describe "delete_image_hash/2" do
    test "a moderator clears the hash and gets the updated image" do
      moderator = moderator_user_fixture()
      image = image_fixture()
      assert image.image_orig_sha512_hash != nil

      assert {:ok, cleared} = Images.delete_image_hash(actor(moderator), to_string(image.id))
      assert cleared.id == image.id
      assert cleared.image_orig_sha512_hash == nil
      assert Repo.reload!(image).image_orig_sha512_hash == nil
    end

    test "an admin clears the hash" do
      admin = admin_user_fixture()
      image = image_fixture()

      assert {:ok, cleared} = Images.delete_image_hash(actor(admin), to_string(image.id))
      assert cleared.id == image.id
      assert Repo.reload!(image).image_orig_sha512_hash == nil
    end

    test "a regular user cannot clear the hash and it stays set" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert Images.delete_image_hash(actor(user), to_string(image.id)) == {:error, :unauthorized}
      assert Repo.reload!(image).image_orig_sha512_hash == image.image_orig_sha512_hash
      assert moderation_log_count() == 0
    end

    test "an anonymous actor cannot clear the hash and it stays set" do
      # A nil actor fails the :hide authorization on the loaded image, so this is
      # a clean unauthorized rather than a crash.
      image = image_fixture()

      assert Images.delete_image_hash(actor(), to_string(image.id)) == {:error, :unauthorized}
      assert Repo.reload!(image).image_orig_sha512_hash == image.image_orig_sha512_hash
      assert moderation_log_count() == 0
    end

    test "a successful clear writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, _} = Images.delete_image_hash(actor(moderator), to_string(image.id))

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.Hash:delete"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Cleared hash of image #{image.id}"
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, cleared} = Images.delete_image_hash(actor(moderator), image.id)
      assert cleared.id == image.id
    end

    test "a moderator with an unknown well-formed id is not found" do
      # Missing image locators resolve to not-found before authorization.
      moderator = moderator_user_fixture()

      assert Images.delete_image_hash(actor(moderator), "2147483647") == {:error, :not_found}
      assert moderation_log_count() == 0
    end

    test "an admin with an unknown well-formed id is not found" do
      # Missing image locators resolve to not-found before authorization.
      admin = admin_user_fixture()

      assert Images.delete_image_hash(actor(admin), "2147483647") == {:error, :not_found}
      assert moderation_log_count() == 0
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.delete_image_hash(actor(moderator), "not-a-number") == {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      # IntegerId.parse rejects a value the integer column could not hold before
      # the row is ever queried, ahead of any authorization.
      moderator = moderator_user_fixture()

      assert Images.delete_image_hash(actor(moderator), "99999999999999999999") ==
               {:error, :not_found}
    end
  end

  describe "create_image_repair/2" do
    test "a moderator flags the image for reprocessing and gets the image" do
      # The engine writes with update_all, so the returned struct still carries
      # the pre-repair flags; the cleared flags show on reload.
      moderator = moderator_user_fixture()
      image = image_fixture(processed: true, thumbnails_generated: true)

      assert {:ok, repaired} = Images.create_image_repair(actor(moderator), to_string(image.id))
      assert repaired.id == image.id

      reloaded = Repo.reload!(image)
      refute reloaded.processed
      refute reloaded.thumbnails_generated
    end

    test "an admin flags the image for reprocessing" do
      admin = admin_user_fixture()
      image = image_fixture(processed: true, thumbnails_generated: true)

      assert {:ok, repaired} = Images.create_image_repair(actor(admin), to_string(image.id))
      assert repaired.id == image.id

      reloaded = Repo.reload!(image)
      refute reloaded.processed
      refute reloaded.thumbnails_generated
    end

    test "a regular user cannot repair and the flags stay set" do
      user = confirmed_user_fixture()
      image = image_fixture(processed: true, thumbnails_generated: true)

      assert Images.create_image_repair(actor(user), to_string(image.id)) ==
               {:error, :unauthorized}

      reloaded = Repo.reload!(image)
      assert reloaded.processed
      assert reloaded.thumbnails_generated
      assert moderation_log_count() == 0
    end

    test "an anonymous actor cannot repair and the flags stay set" do
      # A nil actor fails the :hide authorization on the loaded image, so this is
      # a clean unauthorized rather than a crash.
      image = image_fixture(processed: true, thumbnails_generated: true)

      assert Images.create_image_repair(actor(), to_string(image.id)) == {:error, :unauthorized}

      reloaded = Repo.reload!(image)
      assert reloaded.processed
      assert reloaded.thumbnails_generated
      assert moderation_log_count() == 0
    end

    test "a successful repair writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, _} = Images.create_image_repair(actor(moderator), to_string(image.id))

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.Repair:create"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Repaired image #{image.id}"
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, repaired} = Images.create_image_repair(actor(moderator), image.id)
      assert repaired.id == image.id
    end

    test "a moderator with an unknown well-formed id is not found" do
      # Missing image locators resolve to not-found before authorization.
      moderator = moderator_user_fixture()

      assert Images.create_image_repair(actor(moderator), "2147483647") == {:error, :not_found}
      assert moderation_log_count() == 0
    end

    test "an admin with an unknown well-formed id is not found" do
      # Missing image locators resolve to not-found before authorization.
      admin = admin_user_fixture()

      assert Images.create_image_repair(actor(admin), "2147483647") == {:error, :not_found}
      assert moderation_log_count() == 0
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.create_image_repair(actor(moderator), "not-a-number") == {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      # IntegerId.parse rejects a value the integer column could not hold before
      # the row is ever queried, ahead of any authorization.
      moderator = moderator_user_fixture()

      assert Images.create_image_repair(actor(moderator), "99999999999999999999") ==
               {:error, :not_found}
    end
  end

  describe "delete_image_source_history/2" do
    test "a moderator clears the source history and source_url and gets the image" do
      moderator = moderator_user_fixture()
      image = image_fixture(source_url: "https://example.com/artwork")
      source_change_fixture(image)
      source_change_fixture(image)
      assert source_change_count(image) == 2

      assert {:ok, cleared} =
               Images.delete_image_source_history(actor(moderator), to_string(image.id))

      assert cleared.id == image.id

      reloaded = Repo.reload!(image)
      assert reloaded.source_url == nil
      assert source_change_count(image) == 0
    end

    test "an admin clears the source history and source_url" do
      admin = admin_user_fixture()
      image = image_fixture(source_url: "https://example.com/artwork")
      source_change_fixture(image)

      assert {:ok, cleared} =
               Images.delete_image_source_history(actor(admin), to_string(image.id))

      assert cleared.id == image.id

      reloaded = Repo.reload!(image)
      assert reloaded.source_url == nil
      assert source_change_count(image) == 0
    end

    test "a regular user cannot clear the history and it stays intact" do
      user = confirmed_user_fixture()
      image = image_fixture(source_url: "https://example.com/artwork")
      source_change_fixture(image)

      assert Images.delete_image_source_history(actor(user), to_string(image.id)) ==
               {:error, :unauthorized}

      reloaded = Repo.reload!(image)
      assert reloaded.source_url == "https://example.com/artwork"
      assert source_change_count(image) == 1
      assert moderation_log_count() == 0
    end

    test "an anonymous actor cannot clear the history and it stays intact" do
      # A nil actor fails the :hide authorization on the loaded image, so this is
      # a clean unauthorized rather than a crash.
      image = image_fixture(source_url: "https://example.com/artwork")
      source_change_fixture(image)

      assert Images.delete_image_source_history(actor(), to_string(image.id)) ==
               {:error, :unauthorized}

      reloaded = Repo.reload!(image)
      assert reloaded.source_url == "https://example.com/artwork"
      assert source_change_count(image) == 1
      assert moderation_log_count() == 0
    end

    test "a successful clear writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, _} = Images.delete_image_source_history(actor(moderator), to_string(image.id))

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.SourceHistory:delete"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Deleted source history for image #{image.id}"
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, cleared} = Images.delete_image_source_history(actor(moderator), image.id)
      assert cleared.id == image.id
    end

    test "a moderator with an unknown well-formed id is not found" do
      # Missing image locators resolve to not-found before authorization.
      moderator = moderator_user_fixture()

      assert Images.delete_image_source_history(actor(moderator), "2147483647") ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "an admin with an unknown well-formed id is not found" do
      # Missing image locators resolve to not-found before authorization.
      admin = admin_user_fixture()

      assert Images.delete_image_source_history(actor(admin), "2147483647") ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.delete_image_source_history(actor(moderator), "not-a-number") ==
               {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      # IntegerId.parse rejects a value the integer column could not hold before
      # the row is ever queried, ahead of any authorization.
      moderator = moderator_user_fixture()

      assert Images.delete_image_source_history(actor(moderator), "99999999999999999999") ==
               {:error, :not_found}
    end
  end

  describe "list_image_faves/2" do
    test "an anonymous actor gets the faves without vote data on a visible image" do
      image = image_fixture()

      assert {:ok, {loaded, has_votes}} = Images.list_image_faves(actor(), to_string(image.id))
      assert loaded.id == image.id
      refute has_votes

      # Faves are always preloaded; the tamper-only vote associations are not.
      assert Ecto.assoc_loaded?(loaded.faves)
      refute Ecto.assoc_loaded?(loaded.upvotes)
      refute Ecto.assoc_loaded?(loaded.downvotes)
      refute Ecto.assoc_loaded?(loaded.hides)
    end

    test "a regular user gets the faves without vote data on a visible image" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert {:ok, {loaded, has_votes}} =
               Images.list_image_faves(actor(user), to_string(image.id))

      assert loaded.id == image.id
      refute has_votes

      assert Ecto.assoc_loaded?(loaded.faves)
      refute Ecto.assoc_loaded?(loaded.upvotes)
      refute Ecto.assoc_loaded?(loaded.downvotes)
      refute Ecto.assoc_loaded?(loaded.hides)
    end

    test "faves are preloaded with their user for any actor" do
      faver = confirmed_user_fixture()
      image = image_fixture()
      fave!(image, faver)

      assert {:ok, {loaded, _has_votes}} = Images.list_image_faves(actor(), to_string(image.id))

      [fave] = loaded.faves
      assert fave.user.id == faver.id
    end

    test "a moderator gets has_votes true with the vote associations preloaded" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, {loaded, has_votes}} =
               Images.list_image_faves(actor(moderator), to_string(image.id))

      assert loaded.id == image.id
      assert has_votes

      assert Ecto.assoc_loaded?(loaded.faves)
      assert Ecto.assoc_loaded?(loaded.upvotes)
      assert Ecto.assoc_loaded?(loaded.downvotes)
      assert Ecto.assoc_loaded?(loaded.hides)
    end

    test "an admin gets has_votes true" do
      admin = admin_user_fixture()
      image = image_fixture()

      assert {:ok, {loaded, has_votes}} =
               Images.list_image_faves(actor(admin), to_string(image.id))

      assert loaded.id == image.id
      assert has_votes
    end

    test "a moderator's vote associations carry their users" do
      moderator = moderator_user_fixture()
      upvoter = confirmed_user_fixture()
      downvoter = confirmed_user_fixture()
      hider = confirmed_user_fixture()
      image = image_fixture()

      vote!(image, upvoter, true)
      vote!(image, downvoter, false)
      hide!(image, hider)

      assert {:ok, {loaded, true}} =
               Images.list_image_faves(actor(moderator), to_string(image.id))

      assert [%{user: %{id: up_id}}] = loaded.upvotes
      assert up_id == upvoter.id
      assert [%{user: %{id: down_id}}] = loaded.downvotes
      assert down_id == downvoter.id
      assert [%{user: %{id: hide_id}}] = loaded.hides
      assert hide_id == hider.id
    end

    test "a hidden image is unauthorized for a regular user" do
      user = confirmed_user_fixture()
      image = image_fixture(hidden_from_users: true)

      assert Images.list_image_faves(actor(user), to_string(image.id)) == {:error, :unauthorized}
    end

    test "a hidden image is unauthorized for an anonymous actor" do
      image = image_fixture(hidden_from_users: true)

      assert Images.list_image_faves(actor(), to_string(image.id)) == {:error, :unauthorized}
    end

    test "a hidden image is listable by a moderator with has_votes true" do
      moderator = moderator_user_fixture()
      image = image_fixture(hidden_from_users: true)

      assert {:ok, {loaded, true}} =
               Images.list_image_faves(actor(moderator), to_string(image.id))

      assert loaded.id == image.id
    end

    test "accepts an integer id" do
      image = image_fixture()

      assert {:ok, {loaded, false}} = Images.list_image_faves(actor(), image.id)
      assert loaded.id == image.id
    end

    test "an unknown well-formed id is not found for an anonymous actor" do
      # Missing image locators resolve to not-found before authorization.
      assert Images.list_image_faves(actor(), "2147483647") == {:error, :not_found}
    end

    test "an unknown well-formed id is not found for a regular user" do
      assert Images.list_image_faves(actor(confirmed_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "an unknown well-formed id is not found for a moderator" do
      assert Images.list_image_faves(actor(moderator_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "an unknown well-formed id is not found for an admin" do
      # Missing image locators resolve to not-found before authorization.
      assert Images.list_image_faves(actor(admin_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "a non-castable id is not found" do
      assert Images.list_image_faves(actor(), "not-a-number") == {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      # IntegerId.parse rejects a value the integer column could not hold before
      # the row is ever queried, ahead of any authorization.
      assert Images.list_image_faves(actor(), "99999999999999999999") == {:error, :not_found}
    end
  end

  describe "load_hidable_image/3" do
    test "a moderator loads a known image" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, loaded} = Images.load_hidable_image(actor(moderator), to_string(image.id))
      assert loaded.id == image.id
    end

    test "a moderator whose first request has no fingerprint loads the image" do
      image = image_fixture()
      actor = actor(moderator_user_fixture(), fingerprint: nil)

      assert {:ok, loaded} = Images.load_hidable_image(actor, image.id)
      assert loaded.id == image.id
    end

    test "a banned moderator is rejected" do
      actor = actor(moderator_user_fixture(), ban: @ban)

      assert Images.load_hidable_image(actor, image_fixture().id) == {:error, :ban}
    end

    test "an admin loads a known image" do
      admin = admin_user_fixture()
      image = image_fixture()

      assert {:ok, loaded} = Images.load_hidable_image(actor(admin), to_string(image.id))
      assert loaded.id == image.id
    end

    test "a regular user cannot load the image" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert Images.load_hidable_image(actor(user), to_string(image.id)) ==
               {:error, :unauthorized}
    end

    test "an anonymous actor cannot load the image" do
      image = image_fixture()

      assert Images.load_hidable_image(actor(), to_string(image.id)) ==
               {:error, :unauthorized}
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, loaded} = Images.load_hidable_image(actor(moderator), image.id)
      assert loaded.id == image.id
    end

    test "a moderator with an unknown well-formed id is not found" do
      # Missing image locators resolve to not-found before authorization.
      moderator = moderator_user_fixture()

      assert Images.load_hidable_image(actor(moderator), "2147483647") ==
               {:error, :not_found}
    end

    test "an admin with an unknown well-formed id is not found" do
      # Missing image locators resolve to not-found before authorization.
      admin = admin_user_fixture()

      assert Images.load_hidable_image(actor(admin), "2147483647") == {:error, :not_found}
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.load_hidable_image(actor(moderator), "not-a-number") == {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      moderator = moderator_user_fixture()

      assert Images.load_hidable_image(actor(moderator), "99999999999999999999") ==
               {:error, :not_found}
    end
  end

  describe "update_image_scratchpad/3" do
    test "a moderator stores the scratchpad and gets the image" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, updated} =
               Images.update_image_scratchpad(actor(moderator), to_string(image.id), %{
                 "scratchpad" => "watch closely"
               })

      assert updated.id == image.id
      assert updated.scratchpad == "watch closely"
      assert Repo.reload!(image).scratchpad == "watch closely"
    end

    test "an admin stores the scratchpad" do
      admin = admin_user_fixture()
      image = image_fixture()

      assert {:ok, _updated} =
               Images.update_image_scratchpad(actor(admin), to_string(image.id), %{
                 "scratchpad" => "noted"
               })

      assert Repo.reload!(image).scratchpad == "noted"
    end

    test "a blank scratchpad clears the field to nil" do
      moderator = moderator_user_fixture()
      image = image_fixture(scratchpad: "existing note")

      assert {:ok, updated} =
               Images.update_image_scratchpad(actor(moderator), to_string(image.id), %{
                 "scratchpad" => ""
               })

      assert updated.scratchpad == nil
      assert Repo.reload!(image).scratchpad == nil
    end

    test "a successful update writes an exact moderation log with the new value" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, _} =
               Images.update_image_scratchpad(actor(moderator), to_string(image.id), %{
                 "scratchpad" => "watch closely"
               })

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.Scratchpad:update"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Updated mod notes on image #{image.id} (watch closely)"
    end

    test "clearing the scratchpad logs an empty value in the parentheses" do
      moderator = moderator_user_fixture()
      image = image_fixture(scratchpad: "existing note")

      assert {:ok, _} =
               Images.update_image_scratchpad(actor(moderator), to_string(image.id), %{
                 "scratchpad" => ""
               })

      log = only_moderation_log!()
      assert log.body == "Updated mod notes on image #{image.id} ()"
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, updated} =
               Images.update_image_scratchpad(actor(moderator), image.id, %{
                 "scratchpad" => "noted"
               })

      assert updated.scratchpad == "noted"
    end

    test "a regular user cannot update and the scratchpad and log stay untouched" do
      user = confirmed_user_fixture()
      image = image_fixture(scratchpad: "existing note")

      assert Images.update_image_scratchpad(actor(user), to_string(image.id), %{
               "scratchpad" => "new"
             }) ==
               {:error, :unauthorized}

      assert Repo.reload!(image).scratchpad == "existing note"
      assert moderation_log_count() == 0
    end

    test "an anonymous actor cannot update and the scratchpad and log stay untouched" do
      image = image_fixture(scratchpad: "existing note")

      assert Images.update_image_scratchpad(actor(), to_string(image.id), %{"scratchpad" => "new"}) ==
               {:error, :unauthorized}

      assert Repo.reload!(image).scratchpad == "existing note"
      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown well-formed id is not found and writes no log" do
      moderator = moderator_user_fixture()

      assert Images.update_image_scratchpad(actor(moderator), "2147483647", %{
               "scratchpad" => "new"
             }) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "an admin with an unknown well-formed id is not found and writes no log" do
      admin = admin_user_fixture()

      assert Images.update_image_scratchpad(actor(admin), "2147483647", %{"scratchpad" => "new"}) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_image_scratchpad(actor(moderator), "not-a-number", %{
               "scratchpad" => "new"
             }) ==
               {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_image_scratchpad(actor(moderator), "99999999999999999999", %{
               "scratchpad" => "new"
             }) ==
               {:error, :not_found}
    end
  end

  describe "create_image_subscription/2" do
    test "a regular user subscribes to a visible image and the row is created" do
      # The :show authorization admits a regular user on a visible image, so
      # subscribing is not staff-gated.
      user = confirmed_user_fixture()
      image = image_fixture()
      spy(Exq)

      assert {:ok, subscribed} =
               Images.create_image_subscription(actor(user), to_string(image.id))

      assert subscribed.id == image.id
      assert Images.subscribed?(image, user)
      assert {:enqueue, image_reindex(image)} in history(Exq)
    end

    test "a moderator subscribes to a visible image" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, _} = Images.create_image_subscription(actor(moderator), to_string(image.id))
      assert Images.subscribed?(image, moderator)
    end

    test "subscribing twice is idempotent and stays subscribed" do
      # create_subscription inserts with on_conflict: :nothing, so a repeat is a
      # successful no-op rather than a changeset error.
      user = confirmed_user_fixture()
      image = image_fixture()

      assert {:ok, _} = Images.create_image_subscription(actor(user), to_string(image.id))
      assert {:ok, _} = Images.create_image_subscription(actor(user), to_string(image.id))
      assert Images.subscribed?(image, user)
    end

    test "a banned actor can subscribe" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert {:ok, _} =
               Images.create_image_subscription(actor(user, ban: @ban), to_string(image.id))

      assert Images.subscribed?(image, user)
    end

    test "accepts an integer id" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert {:ok, subscribed} = Images.create_image_subscription(actor(user), image.id)
      assert subscribed.id == image.id
    end

    test "an unknown well-formed id is not found for an anonymous actor" do
      # Missing image locators resolve to not-found before authorization.
      assert Images.create_image_subscription(actor(), "2147483647") == {:error, :not_found}
    end

    test "an unknown well-formed id is not found for a regular user" do
      assert Images.create_image_subscription(actor(confirmed_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "an unknown well-formed id is not found for a moderator" do
      assert Images.create_image_subscription(actor(moderator_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "an unknown well-formed id is not found for an admin" do
      # Missing image locators resolve to not-found before authorization.
      assert Images.create_image_subscription(actor(admin_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "a non-castable id is not found" do
      assert Images.create_image_subscription(actor(confirmed_user_fixture()), "not-a-number") ==
               {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      # IntegerId.parse rejects a value the integer column could not hold before
      # the row is ever queried, ahead of any authorization.
      assert Images.create_image_subscription(
               actor(confirmed_user_fixture()),
               "99999999999999999999"
             ) ==
               {:error, :not_found}
    end
  end

  describe "delete_image_subscription/2" do
    test "a regular user unsubscribes from a visible image and the row is removed" do
      user = confirmed_user_fixture()
      image = image_fixture()
      {:ok, _} = Images.create_subscription(image, user)
      assert Images.subscribed?(image, user)
      spy(Exq)

      assert {:ok, unsubscribed} =
               Images.delete_image_subscription(actor(user), to_string(image.id))

      assert unsubscribed.id == image.id
      refute Images.subscribed?(image, user)
      assert {:enqueue, image_reindex(image)} in history(Exq)
    end

    test "unsubscribing with no existing subscription still succeeds" do
      # delete_subscription runs an unconditional delete and hard-matches {:ok, _},
      # so the absence of a row is not an error.
      user = confirmed_user_fixture()
      image = image_fixture()
      refute Images.subscribed?(image, user)

      assert {:ok, unsubscribed} =
               Images.delete_image_subscription(actor(user), to_string(image.id))

      assert unsubscribed.id == image.id
      refute Images.subscribed?(image, user)
    end

    test "a banned actor can unsubscribe" do
      user = confirmed_user_fixture()
      image = image_fixture()
      {:ok, _} = Images.create_subscription(image, user)

      assert {:ok, _} =
               Images.delete_image_subscription(actor(user, ban: @ban), to_string(image.id))

      refute Images.subscribed?(image, user)
    end

    test "accepts an integer id" do
      user = confirmed_user_fixture()
      image = image_fixture()
      {:ok, _} = Images.create_subscription(image, user)

      assert {:ok, unsubscribed} = Images.delete_image_subscription(actor(user), image.id)
      assert unsubscribed.id == image.id
      refute Images.subscribed?(image, user)
    end

    test "an unknown well-formed id is not found for an anonymous actor" do
      assert Images.delete_image_subscription(actor(), "2147483647") == {:error, :not_found}
    end

    test "an unknown well-formed id is not found for a regular user" do
      assert Images.delete_image_subscription(actor(confirmed_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "an unknown well-formed id is not found for a moderator" do
      assert Images.delete_image_subscription(actor(moderator_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "an unknown well-formed id is not found for an admin" do
      assert Images.delete_image_subscription(actor(admin_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "a non-castable id is not found" do
      assert Images.delete_image_subscription(actor(confirmed_user_fixture()), "not-a-number") ==
               {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      assert Images.delete_image_subscription(
               actor(confirmed_user_fixture()),
               "99999999999999999999"
             ) ==
               {:error, :not_found}
    end
  end

  describe "create_image_approve/2" do
    test "queues the image's comments for reindexing with the approved image" do
      image = image_fixture(approved: false)
      spy(Exq)

      assert {:ok, _} = Images.create_image_approve(actor(moderator_user_fixture()), image.id)

      reindex = [Exq, "indexing", Philomena.IndexWorker, ["Comments", "image_id", [image.id]]]
      assert {:enqueue, reindex} in history(Exq)
    end

    test "a moderator approves an unapproved image and gets the image" do
      moderator = moderator_user_fixture()
      image = image_fixture(approved: false)

      assert {:ok, approved} = Images.create_image_approve(actor(moderator), to_string(image.id))
      assert approved.id == image.id
      assert approved.approved
      assert Repo.reload!(image).approved
    end

    test "an admin approves an unapproved image" do
      admin = admin_user_fixture()
      image = image_fixture(approved: false)

      assert {:ok, _} = Images.create_image_approve(actor(admin), to_string(image.id))
      assert Repo.reload!(image).approved
    end

    test "approving increments the uploader's image count" do
      moderator = moderator_user_fixture()
      uploader = confirmed_user_fixture()
      image = image_fixture(approved: false, user_id: uploader.id)
      assert Repo.reload!(uploader).images_count == 0

      assert {:ok, _} = Images.create_image_approve(actor(moderator), to_string(image.id))
      assert Repo.reload!(uploader).images_count == 1
    end

    test "a successful approval writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture(approved: false)

      assert {:ok, _} = Images.create_image_approve(actor(moderator), to_string(image.id))

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.Approve:create"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Approved image #{image.id}"
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      image = image_fixture(approved: false)

      assert {:ok, approved} = Images.create_image_approve(actor(moderator), image.id)
      assert approved.id == image.id
    end

    test "suggests verification when approval reaches the uploader's fifth image" do
      moderator = moderator_user_fixture()
      uploader = confirmed_user_fixture()
      rule_fixture(name: "Verification")

      uploader
      |> Ecto.Changeset.change(images_count: 4)
      |> Repo.update!()

      image = image_fixture(approved: false, user_id: uploader.id)

      assert {:ok, approved} = Images.create_image_approve(actor(moderator), image.id)
      assert approved.approved
      assert Repo.reload!(uploader).images_count == 5

      assert %Report{reported_user_id: uploader_id, reason: reason, system: true} =
               Repo.one!(from report in Report, where: report.reported_user_id == ^uploader.id)

      assert uploader_id == uploader.id

      assert reason ==
               "User has uploaded enough approved images to be considered for verification."
    end

    test "an already-approved image returns a changeset error with no log or state change" do
      moderator = moderator_user_fixture()
      image = image_fixture(approved: true)

      assert {:error, %{errors: [approved: {"must be false", []}]}} =
               Images.create_image_approve(actor(moderator), to_string(image.id))

      assert Repo.reload!(image).approved
      assert moderation_log_count() == 0
    end

    test "a regular user on an already-approved image is unauthorized" do
      # Authorization runs before the approved-state check, so a regular user
      # fails :approve and never reaches the approved-state validation.
      user = confirmed_user_fixture()
      image = image_fixture(approved: true)

      assert Images.create_image_approve(actor(user), to_string(image.id)) ==
               {:error, :unauthorized}

      assert moderation_log_count() == 0
    end

    test "a regular user cannot approve an unapproved image and it stays unapproved" do
      user = confirmed_user_fixture()
      image = image_fixture(approved: false)

      assert Images.create_image_approve(actor(user), to_string(image.id)) ==
               {:error, :unauthorized}

      refute Repo.reload!(image).approved
      assert moderation_log_count() == 0
    end

    test "an anonymous actor cannot approve an unapproved image" do
      image = image_fixture(approved: false)

      assert Images.create_image_approve(actor(), to_string(image.id)) == {:error, :unauthorized}
      refute Repo.reload!(image).approved
      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown well-formed id is not found" do
      # Missing image locators resolve to not-found before authorization.
      moderator = moderator_user_fixture()

      assert Images.create_image_approve(actor(moderator), "2147483647") == {:error, :not_found}
      assert moderation_log_count() == 0
    end

    test "an admin with an unknown well-formed id is not found" do
      # Missing image locators resolve to not-found before authorization.
      admin = admin_user_fixture()

      assert Images.create_image_approve(actor(admin), "2147483647") == {:error, :not_found}
      assert moderation_log_count() == 0
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.create_image_approve(actor(moderator), "not-a-number") == {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      moderator = moderator_user_fixture()

      assert Images.create_image_approve(actor(moderator), "99999999999999999999") ==
               {:error, :not_found}
    end
  end

  describe "update_image_comment_lock/3" do
    test "a moderator locks comments, clearing commenting_allowed" do
      moderator = moderator_user_fixture()
      image = image_fixture(commenting_allowed: true)

      assert {:ok, locked} =
               Images.update_image_comment_lock(actor(moderator), to_string(image.id), true)

      assert locked.id == image.id
      refute locked.commenting_allowed
      refute Repo.reload!(image).commenting_allowed
    end

    test "an admin locks comments" do
      admin = admin_user_fixture()
      image = image_fixture(commenting_allowed: true)

      assert {:ok, _} = Images.update_image_comment_lock(actor(admin), to_string(image.id), true)
      refute Repo.reload!(image).commenting_allowed
    end

    test "a moderator unlocks comments, setting commenting_allowed" do
      moderator = moderator_user_fixture()
      image = image_fixture(commenting_allowed: false)

      assert {:ok, unlocked} =
               Images.update_image_comment_lock(actor(moderator), to_string(image.id), false)

      assert unlocked.id == image.id
      assert unlocked.commenting_allowed
      assert Repo.reload!(image).commenting_allowed
    end

    test "locking writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture(commenting_allowed: true)

      assert {:ok, _} =
               Images.update_image_comment_lock(actor(moderator), to_string(image.id), true)

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.CommentLock:create"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Locked comments on image #{image.id}"
    end

    test "unlocking writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture(commenting_allowed: false)

      assert {:ok, _} =
               Images.update_image_comment_lock(actor(moderator), to_string(image.id), false)

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.CommentLock:delete"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Unlocked comments on image #{image.id}"
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      image = image_fixture(commenting_allowed: true)

      assert {:ok, locked} = Images.update_image_comment_lock(actor(moderator), image.id, true)
      assert locked.id == image.id
    end

    test "a regular user cannot lock comments and the flag stays set" do
      user = confirmed_user_fixture()
      image = image_fixture(commenting_allowed: true)

      assert Images.update_image_comment_lock(actor(user), to_string(image.id), true) ==
               {:error, :unauthorized}

      assert Repo.reload!(image).commenting_allowed
      assert moderation_log_count() == 0
    end

    test "an anonymous actor cannot lock comments and the flag stays set" do
      image = image_fixture(commenting_allowed: true)

      assert Images.update_image_comment_lock(actor(), to_string(image.id), true) ==
               {:error, :unauthorized}

      assert Repo.reload!(image).commenting_allowed
      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown well-formed id is not found and writes no log" do
      # Missing image locators resolve to not-found before authorization.
      moderator = moderator_user_fixture()

      assert Images.update_image_comment_lock(actor(moderator), "2147483647", true) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "an admin with an unknown well-formed id is not found and writes no log" do
      # Missing image locators resolve to not-found before authorization.
      admin = admin_user_fixture()

      assert Images.update_image_comment_lock(actor(admin), "2147483647", true) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_image_comment_lock(actor(moderator), "not-a-number", true) ==
               {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_image_comment_lock(actor(moderator), "99999999999999999999", true) ==
               {:error, :not_found}
    end
  end

  describe "update_image_description_lock/3" do
    test "a moderator locks description editing, clearing description_editing_allowed" do
      moderator = moderator_user_fixture()
      image = image_fixture(description_editing_allowed: true)

      assert {:ok, locked} =
               Images.update_image_description_lock(actor(moderator), to_string(image.id), true)

      assert locked.id == image.id
      refute locked.description_editing_allowed
      refute Repo.reload!(image).description_editing_allowed
    end

    test "an admin locks description editing" do
      admin = admin_user_fixture()
      image = image_fixture(description_editing_allowed: true)

      assert {:ok, _} =
               Images.update_image_description_lock(actor(admin), to_string(image.id), true)

      refute Repo.reload!(image).description_editing_allowed
    end

    test "a moderator unlocks description editing, setting description_editing_allowed" do
      moderator = moderator_user_fixture()
      image = image_fixture(description_editing_allowed: false)

      assert {:ok, unlocked} =
               Images.update_image_description_lock(actor(moderator), to_string(image.id), false)

      assert unlocked.id == image.id
      assert unlocked.description_editing_allowed
      assert Repo.reload!(image).description_editing_allowed
    end

    test "locking writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture(description_editing_allowed: true)

      assert {:ok, _} =
               Images.update_image_description_lock(actor(moderator), to_string(image.id), true)

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.DescriptionLock:create"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Locked description editing on image #{image.id}"
    end

    test "unlocking writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture(description_editing_allowed: false)

      assert {:ok, _} =
               Images.update_image_description_lock(actor(moderator), to_string(image.id), false)

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.DescriptionLock:delete"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Unlocked description editing on image #{image.id}"
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      image = image_fixture(description_editing_allowed: true)

      assert {:ok, locked} =
               Images.update_image_description_lock(actor(moderator), image.id, true)

      assert locked.id == image.id
    end

    test "a regular user cannot lock description editing and the flag stays set" do
      user = confirmed_user_fixture()
      image = image_fixture(description_editing_allowed: true)

      assert Images.update_image_description_lock(actor(user), to_string(image.id), true) ==
               {:error, :unauthorized}

      assert Repo.reload!(image).description_editing_allowed
      assert moderation_log_count() == 0
    end

    test "an anonymous actor cannot lock description editing and the flag stays set" do
      image = image_fixture(description_editing_allowed: true)

      assert Images.update_image_description_lock(actor(), to_string(image.id), true) ==
               {:error, :unauthorized}

      assert Repo.reload!(image).description_editing_allowed
      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown well-formed id is not found and writes no log" do
      # Missing image locators resolve to not-found before authorization.
      moderator = moderator_user_fixture()

      assert Images.update_image_description_lock(actor(moderator), "2147483647", true) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "an admin with an unknown well-formed id is not found and writes no log" do
      # Missing image locators resolve to not-found before authorization.
      admin = admin_user_fixture()

      assert Images.update_image_description_lock(actor(admin), "2147483647", true) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_image_description_lock(actor(moderator), "not-a-number", true) ==
               {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_image_description_lock(actor(moderator), "99999999999999999999", true) ==
               {:error, :not_found}
    end
  end

  describe "update_image_tag_lock/3" do
    test "a moderator locks tags, clearing tag_editing_allowed" do
      moderator = moderator_user_fixture()
      image = image_fixture(tag_editing_allowed: true)

      assert {:ok, locked} =
               Images.update_image_tag_lock(actor(moderator), to_string(image.id), true)

      assert locked.id == image.id
      refute locked.tag_editing_allowed
      refute Repo.reload!(image).tag_editing_allowed
    end

    test "an admin locks tags" do
      admin = admin_user_fixture()
      image = image_fixture(tag_editing_allowed: true)

      assert {:ok, _} = Images.update_image_tag_lock(actor(admin), to_string(image.id), true)
      refute Repo.reload!(image).tag_editing_allowed
    end

    test "a moderator unlocks tags, setting tag_editing_allowed" do
      moderator = moderator_user_fixture()
      image = image_fixture(tag_editing_allowed: false)

      assert {:ok, unlocked} =
               Images.update_image_tag_lock(actor(moderator), to_string(image.id), false)

      assert unlocked.id == image.id
      assert unlocked.tag_editing_allowed
      assert Repo.reload!(image).tag_editing_allowed
    end

    test "locking writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture(tag_editing_allowed: true)

      assert {:ok, _} = Images.update_image_tag_lock(actor(moderator), to_string(image.id), true)

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.TagLock:create"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Locked tags on image #{image.id}"
    end

    test "unlocking writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture(tag_editing_allowed: false)

      assert {:ok, _} = Images.update_image_tag_lock(actor(moderator), to_string(image.id), false)

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.TagLock:delete"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Unlocked tags on image #{image.id}"
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      image = image_fixture(tag_editing_allowed: true)

      assert {:ok, locked} = Images.update_image_tag_lock(actor(moderator), image.id, true)
      assert locked.id == image.id
    end

    test "a regular user cannot lock tags and the flag stays set" do
      user = confirmed_user_fixture()
      image = image_fixture(tag_editing_allowed: true)

      assert Images.update_image_tag_lock(actor(user), to_string(image.id), true) ==
               {:error, :unauthorized}

      assert Repo.reload!(image).tag_editing_allowed
      assert moderation_log_count() == 0
    end

    test "an anonymous actor cannot lock tags and the flag stays set" do
      image = image_fixture(tag_editing_allowed: true)

      assert Images.update_image_tag_lock(actor(), to_string(image.id), true) ==
               {:error, :unauthorized}

      assert Repo.reload!(image).tag_editing_allowed
      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown well-formed id is not found and writes no log" do
      # Missing image locators resolve to not-found before authorization.
      moderator = moderator_user_fixture()

      assert Images.update_image_tag_lock(actor(moderator), "2147483647", true) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "an admin with an unknown well-formed id is not found and writes no log" do
      # Missing image locators resolve to not-found before authorization.
      admin = admin_user_fixture()

      assert Images.update_image_tag_lock(actor(admin), "2147483647", true) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_image_tag_lock(actor(moderator), "not-a-number", true) ==
               {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_image_tag_lock(actor(moderator), "99999999999999999999", true) ==
               {:error, :not_found}
    end
  end

  describe "load_hidable_image/3 with :preload" do
    test "the option loads the named associations" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, loaded} =
               Images.load_hidable_image(actor(moderator), to_string(image.id),
                 preload: :locked_tags
               )

      assert loaded.id == image.id
      assert Ecto.assoc_loaded?(loaded.locked_tags)
    end

    test "no associations are loaded by default" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, loaded} = Images.load_hidable_image(actor(moderator), image.id)
      refute Ecto.assoc_loaded?(loaded.locked_tags)
    end
  end

  describe "update_image_locked_tags/3" do
    test "a moderator replaces the locked-tags list" do
      moderator = moderator_user_fixture()
      image = image_fixture()
      tag_fixture(name: "old lock")
      tag_fixture(name: "cute")

      # Seed a starting locked tag, then replace it wholesale.
      {:ok, _} =
        Images.update_image_locked_tags(actor(moderator), image.id, %{"tag_input" => "old lock"})

      assert locked_tag_names(image) == ["old lock"]

      assert {:ok, updated} =
               Images.update_image_locked_tags(actor(moderator), to_string(image.id), %{
                 "tag_input" => "safe, cute"
               })

      assert updated.id == image.id
      assert locked_tag_names(image) == ["cute", "safe"]
    end

    test "an empty tag_input clears the locked-tags list" do
      moderator = moderator_user_fixture()
      image = image_fixture()
      tag_fixture(name: "cute")

      {:ok, _} =
        Images.update_image_locked_tags(actor(moderator), image.id, %{"tag_input" => "safe, cute"})

      assert locked_tag_names(image) == ["cute", "safe"]

      assert {:ok, _} =
               Images.update_image_locked_tags(actor(moderator), to_string(image.id), %{
                 "tag_input" => ""
               })

      assert locked_tag_names(image) == []
    end

    test "an admin replaces the locked-tags list" do
      admin = admin_user_fixture()
      image = image_fixture()

      assert {:ok, _} =
               Images.update_image_locked_tags(actor(admin), to_string(image.id), %{
                 "tag_input" => "safe"
               })

      assert locked_tag_names(image) == ["safe"]
    end

    test "only locks existing tags without expanding implications" do
      moderator = moderator_user_fixture()
      image = image_fixture()
      implied = tag_fixture(name: "locked implied")
      selected = tag_fixture(name: "locked selected")

      selected =
        selected
        |> Repo.preload(:implied_tags)
        |> change()
        |> put_assoc(:implied_tags, [implied])
        |> Repo.update!()

      missing = unique_tag_name()

      assert {:ok, _} =
               Images.update_image_locked_tags(actor(moderator), image.id, %{
                 "tag_input" => "#{selected.name}, #{missing}"
               })

      assert locked_tag_names(image) == [selected.name]
      assert Repo.get_by(Tag, name: missing) == nil
    end

    test "a successful update writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, _} =
               Images.update_image_locked_tags(actor(moderator), to_string(image.id), %{
                 "tag_input" => "safe, cute"
               })

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.TagLock:update"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Updated list of locked tags on image #{image.id}"
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, updated} =
               Images.update_image_locked_tags(actor(moderator), image.id, %{
                 "tag_input" => "safe"
               })

      assert updated.id == image.id
      assert locked_tag_names(image) == ["safe"]
    end

    test "a regular user cannot update and the list and log stay untouched" do
      user = confirmed_user_fixture()
      image = image_fixture()

      {:ok, _} =
        Images.update_image_locked_tags(actor(moderator_user_fixture()), image.id, %{
          "tag_input" => "safe"
        })

      Repo.delete_all(ModerationLog)

      assert Images.update_image_locked_tags(actor(user), to_string(image.id), %{
               "tag_input" => "cute"
             }) ==
               {:error, :unauthorized}

      assert locked_tag_names(image) == ["safe"]
      assert moderation_log_count() == 0
    end

    test "an anonymous actor cannot update and the list and log stay untouched" do
      image = image_fixture()

      {:ok, _} =
        Images.update_image_locked_tags(actor(moderator_user_fixture()), image.id, %{
          "tag_input" => "safe"
        })

      Repo.delete_all(ModerationLog)

      assert Images.update_image_locked_tags(actor(), to_string(image.id), %{
               "tag_input" => "cute"
             }) ==
               {:error, :unauthorized}

      assert locked_tag_names(image) == ["safe"]
      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown well-formed id is not found and writes no log" do
      moderator = moderator_user_fixture()

      assert Images.update_image_locked_tags(actor(moderator), "2147483647", %{
               "tag_input" => "safe"
             }) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "an admin with an unknown well-formed id is not found and writes no log" do
      admin = admin_user_fixture()

      assert Images.update_image_locked_tags(actor(admin), "2147483647", %{"tag_input" => "safe"}) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_image_locked_tags(actor(moderator), "not-a-number", %{
               "tag_input" => "safe"
             }) ==
               {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_image_locked_tags(actor(moderator), "99999999999999999999", %{
               "tag_input" => "safe"
             }) ==
               {:error, :not_found}
    end
  end

  describe "create_image_feature/2" do
    test "a moderator features a visible image, creating the feature row" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, %ImageFeature{} = feature} =
               Images.create_image_feature(actor(moderator), to_string(image.id))

      assert feature.image_id == image.id
      assert feature.user_id == moderator.id
      assert feature_row_count(image) == 1
    end

    test "an admin features a visible image" do
      admin = admin_user_fixture()
      image = image_fixture()

      assert {:ok, %ImageFeature{}} =
               Images.create_image_feature(actor(admin), to_string(image.id))

      assert feature_row_count(image) == 1
    end

    test "a successful feature writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, _} = Images.create_image_feature(actor(moderator), to_string(image.id))

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.Feature:create"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Featured image #{image.id}"
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, %ImageFeature{}} = Images.create_image_feature(actor(moderator), image.id)
      assert feature_row_count(image) == 1
    end

    test "a deleted image is rejected without a feature or log" do
      moderator = moderator_user_fixture()
      image = image_fixture(hidden_from_users: true)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Images.create_image_feature(actor(moderator), image.id)

      assert %{image: ["cannot be a deleted image"]} = errors_on(changeset)
      assert feature_row_count(image) == 0
      assert moderation_log_count() == 0
    end

    test "a regular user on a hidden image is unauthorized, not deleted" do
      # Authorization runs before the hidden-state check, so a regular user fails
      # :hide and never reaches the deleted branch.
      user = confirmed_user_fixture()
      image = image_fixture(hidden_from_users: true)

      assert Images.create_image_feature(actor(user), to_string(image.id)) ==
               {:error, :unauthorized}

      assert feature_row_count(image) == 0
      assert moderation_log_count() == 0
    end

    test "a regular user cannot feature a visible image" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert Images.create_image_feature(actor(user), to_string(image.id)) ==
               {:error, :unauthorized}

      assert feature_row_count(image) == 0
      assert moderation_log_count() == 0
    end

    test "an anonymous actor cannot feature a visible image" do
      image = image_fixture()

      assert Images.create_image_feature(actor(), to_string(image.id)) == {:error, :unauthorized}
      assert feature_row_count(image) == 0
      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown well-formed id is not found and writes no log" do
      # Missing image locators resolve to not-found before authorization.
      moderator = moderator_user_fixture()

      assert Images.create_image_feature(actor(moderator), "2147483647") == {:error, :not_found}
      assert moderation_log_count() == 0
    end

    test "an admin with an unknown well-formed id is not found and writes no log" do
      # Missing image locators resolve to not-found before authorization.
      admin = admin_user_fixture()

      assert Images.create_image_feature(actor(admin), "2147483647") == {:error, :not_found}
      assert moderation_log_count() == 0
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.create_image_feature(actor(moderator), "not-a-number") == {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      moderator = moderator_user_fixture()

      assert Images.create_image_feature(actor(moderator), "99999999999999999999") ==
               {:error, :not_found}
    end
  end

  describe "update_image_file/3" do
    test "a moderator replaces the file and gets the image" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, updated} =
               Images.update_image_file(actor(moderator), to_string(image.id), media_png_upload())

      assert updated.id == image.id
      assert Repo.reload!(image).image_sha512_hash == png_upload_sha512()
    end

    test "an admin replaces the file" do
      admin = admin_user_fixture()
      image = image_fixture()

      assert {:ok, _} =
               Images.update_image_file(actor(admin), to_string(image.id), media_png_upload())

      assert Repo.reload!(image).image_sha512_hash == png_upload_sha512()
    end

    test "a successful replacement writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, _} =
               Images.update_image_file(actor(moderator), to_string(image.id), media_png_upload())

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.File:update"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Updated file of image #{image.id}"
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, updated} =
               Images.update_image_file(actor(moderator), image.id, media_png_upload())

      assert updated.id == image.id
    end

    test "a file duplicating another image is a changeset error with no log" do
      moderator = moderator_user_fixture()
      dup_sha = png_upload_sha512()
      _other = image_fixture(image_sha512_hash: dup_sha, image_orig_sha512_hash: dup_sha)
      image = image_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Images.update_image_file(actor(moderator), to_string(image.id), media_png_upload())

      assert moderation_log_count() == 0
    end

    test "a missing file is a changeset error with no log" do
      # With no "image" key the upload analysis fails the required-file check, so
      # the engine returns the changeset error the wrapper passes straight
      # through without logging.
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Images.update_image_file(actor(moderator), to_string(image.id), nil)

      assert moderation_log_count() == 0
    end

    test "a moderator replaces a hidden image" do
      moderator = moderator_user_fixture()
      image = image_fixture(hidden_from_users: true, hidden_image_key: "hidden-key")

      assert {:ok, updated} =
               Images.update_image_file(actor(moderator), to_string(image.id), media_png_upload())

      assert updated.id == image.id
      assert updated.hidden_from_users
      assert Repo.reload!(image).image_sha512_hash == png_upload_sha512()
      assert moderation_log_count() == 1
    end

    test "a regular user on a hidden image is unauthorized, not deleted" do
      # Authorization runs before the hidden-state check, so a regular user fails
      # :hide and never reaches the deleted branch.
      user = confirmed_user_fixture()
      image = image_fixture(hidden_from_users: true)

      assert Images.update_image_file(actor(user), to_string(image.id), media_png_upload()) ==
               {:error, :unauthorized}

      assert moderation_log_count() == 0
    end

    test "a regular user cannot replace the file" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert Images.update_image_file(actor(user), to_string(image.id), media_png_upload()) ==
               {:error, :unauthorized}

      assert moderation_log_count() == 0
    end

    test "an anonymous actor cannot replace the file" do
      image = image_fixture()

      assert Images.update_image_file(actor(), to_string(image.id), media_png_upload()) ==
               {:error, :unauthorized}

      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown well-formed id is not found and writes no log" do
      # Missing image locators resolve to not-found before authorization.
      moderator = moderator_user_fixture()

      assert Images.update_image_file(actor(moderator), "2147483647", media_png_upload()) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "an admin with an unknown well-formed id is not found and writes no log" do
      # Missing image locators resolve to not-found before authorization.
      admin = admin_user_fixture()

      assert Images.update_image_file(actor(admin), "2147483647", media_png_upload()) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_image_file(actor(moderator), "not-a-number", media_png_upload()) ==
               {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_image_file(
               actor(moderator),
               "99999999999999999999",
               media_png_upload()
             ) ==
               {:error, :not_found}
    end
  end

  describe "update_image_anonymous/3" do
    test "a moderator sets anonymity, flagging the image anonymous" do
      moderator = moderator_user_fixture()
      image = image_fixture(anonymous: false)

      assert {:ok, updated} = Images.update_anonymous(actor(moderator), to_string(image.id), true)
      assert updated.id == image.id
      assert updated.anonymous
      assert Repo.reload!(image).anonymous
    end

    test "an admin sets anonymity" do
      admin = admin_user_fixture()
      image = image_fixture(anonymous: false)

      assert {:ok, _} = Images.update_anonymous(actor(admin), to_string(image.id), true)
      assert Repo.reload!(image).anonymous
    end

    test "a moderator clears anonymity" do
      moderator = moderator_user_fixture()
      image = image_fixture(anonymous: true)

      assert {:ok, updated} =
               Images.update_anonymous(actor(moderator), to_string(image.id), false)

      assert updated.id == image.id
      refute updated.anonymous
      refute Repo.reload!(image).anonymous
    end

    test "setting anonymity writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture(anonymous: false)

      assert {:ok, _} = Images.update_anonymous(actor(moderator), to_string(image.id), true)

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.Anonymous:create"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Updated anonymity of image #{image.id}"
    end

    test "clearing anonymity writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture(anonymous: true)

      assert {:ok, _} = Images.update_anonymous(actor(moderator), to_string(image.id), false)

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.Anonymous:delete"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Updated anonymity of image #{image.id}"
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      image = image_fixture(anonymous: false)

      assert {:ok, updated} = Images.update_anonymous(actor(moderator), image.id, true)
      assert updated.id == image.id
      assert Repo.reload!(image).anonymous
    end

    test "a regular user is unauthorized on a real image and the flag stays put" do
      # Authorization on :identity_metadata runs before the load, so a regular user is
      # denied without the image ever being touched.
      user = confirmed_user_fixture()
      image = image_fixture(anonymous: false)

      assert Images.update_anonymous(actor(user), to_string(image.id), true) ==
               {:error, :unauthorized}

      refute Repo.reload!(image).anonymous
      assert moderation_log_count() == 0
    end

    test "a regular user with a garbage id is still unauthorized, not not_found" do
      # The :identity_metadata authorization precedes the id parse, so a non-castable id
      # never reaches the not-found path for an unprivileged actor.
      user = confirmed_user_fixture()

      assert Images.update_anonymous(actor(user), "not-a-number", true) == {:error, :unauthorized}
      assert moderation_log_count() == 0
    end

    test "an anonymous actor is unauthorized on a real image" do
      image = image_fixture(anonymous: false)

      assert Images.update_anonymous(actor(), to_string(image.id), true) ==
               {:error, :unauthorized}

      refute Repo.reload!(image).anonymous
      assert moderation_log_count() == 0
    end

    test "an anonymous actor with a garbage id is still unauthorized" do
      assert Images.update_anonymous(actor(), "not-a-number", true) == {:error, :unauthorized}
      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown well-formed id is not found and writes no log" do
      # Missing image locators resolve to not-found before authorization.
      # missing image is a plain not-found rather than unauthorized.
      moderator = moderator_user_fixture()

      assert Images.update_anonymous(actor(moderator), "2147483647", true) == {:error, :not_found}
      assert moderation_log_count() == 0
    end

    test "a moderator with a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_anonymous(actor(moderator), "not-a-number", true) ==
               {:error, :not_found}
    end

    test "a moderator with an out-of-range id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_anonymous(actor(moderator), "99999999999999999999", true) ==
               {:error, :not_found}
    end
  end

  describe "create_image_destroy/2" do
    test "an Image-admin role_map moderator destroys a hidden image, nulling the file" do
      moderator = role_moderator_fixture("Image")
      image = image_fixture(hidden_from_users: true)

      assert {:ok, destroyed} = Images.create_image_destroy(actor(moderator), to_string(image.id))
      assert destroyed.id == image.id
      assert Repo.reload!(image).image == nil
    end

    test "an admin destroys a hidden image" do
      admin = admin_user_fixture()
      image = image_fixture(hidden_from_users: true)

      assert {:ok, _} = Images.create_image_destroy(actor(admin), to_string(image.id))
      assert Repo.reload!(image).image == nil
    end

    test "a successful destroy writes an exact moderation log" do
      admin = admin_user_fixture()
      image = image_fixture(hidden_from_users: true)

      assert {:ok, _} = Images.create_image_destroy(actor(admin), to_string(image.id))

      log = only_moderation_log!()
      assert log.user_id == admin.id
      assert log.type == "Image.Destroy:create"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Hard-deleted image #{image.id}"
    end

    test "accepts an integer id" do
      admin = admin_user_fixture()
      image = image_fixture(hidden_from_users: true)

      assert {:ok, destroyed} = Images.create_image_destroy(actor(admin), image.id)
      assert destroyed.id == image.id
      assert Repo.reload!(image).image == nil
    end

    test "a visible image is not deleted with the file intact and no log" do
      # The precondition requires a hidden image; a still-visible one is refused
      # before any change.
      admin = admin_user_fixture()
      image = image_fixture(hidden_from_users: false)

      assert {:error, %Ecto.Changeset{}} =
               Images.create_image_destroy(actor(admin), to_string(image.id))

      assert Repo.reload!(image).image == image.image
      assert moderation_log_count() == 0
    end

    test "a plain moderator cannot destroy a hidden image and the file stays intact" do
      # :destroy needs an Image-admin role_map grant, which a plain moderator
      # lacks, so this is unauthorized even though the image is hidden.
      moderator = moderator_user_fixture()
      image = image_fixture(hidden_from_users: true)

      assert Images.create_image_destroy(actor(moderator), to_string(image.id)) ==
               {:error, :unauthorized}

      assert Repo.reload!(image).image == image.image
      assert moderation_log_count() == 0
    end

    test "a plain moderator on a visible image is unauthorized, not not_deleted" do
      # Authorization runs before the hidden-state check, so a plain moderator
      # fails :destroy and never reaches the not_deleted branch.
      moderator = moderator_user_fixture()
      image = image_fixture(hidden_from_users: false)

      assert Images.create_image_destroy(actor(moderator), to_string(image.id)) ==
               {:error, :unauthorized}

      assert moderation_log_count() == 0
    end

    test "a regular user cannot destroy a hidden image" do
      user = confirmed_user_fixture()
      image = image_fixture(hidden_from_users: true)

      assert Images.create_image_destroy(actor(user), to_string(image.id)) ==
               {:error, :unauthorized}

      assert Repo.reload!(image).image == image.image
      assert moderation_log_count() == 0
    end

    test "an anonymous actor cannot destroy a hidden image" do
      image = image_fixture(hidden_from_users: true)

      assert Images.create_image_destroy(actor(), to_string(image.id)) == {:error, :unauthorized}
      assert Repo.reload!(image).image == image.image
      assert moderation_log_count() == 0
    end

    test "an Image-admin role_map moderator with an unknown well-formed id is not found" do
      # Missing image locators resolve to not-found before authorization.
      moderator = role_moderator_fixture("Image")

      assert Images.create_image_destroy(actor(moderator), "2147483647") == {:error, :not_found}
      assert moderation_log_count() == 0
    end

    test "an admin with an unknown well-formed id is not found" do
      # Missing image locators resolve to not-found before authorization.
      admin = admin_user_fixture()

      assert Images.create_image_destroy(actor(admin), "2147483647") == {:error, :not_found}
      assert moderation_log_count() == 0
    end

    test "a non-castable id is not found" do
      admin = admin_user_fixture()

      assert Images.create_image_destroy(actor(admin), "not-a-number") == {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      admin = admin_user_fixture()

      assert Images.create_image_destroy(actor(admin), "99999999999999999999") ==
               {:error, :not_found}
    end
  end

  describe "update_image_description/3" do
    test "broadcasts the description and rendered image after persistence" do
      uploader = confirmed_user_fixture()
      image = image_fixture(user_id: uploader.id, description: "Old")
      :ok = Endpoint.subscribe("firehose")

      assert {:ok, {_image, "Old"}} =
               Images.update_image_description(actor(uploader), image.id, %{
                 "description" => "New"
               })

      assert_receive %Broadcast{
        event: "image:description_update",
        payload: %{image_id: image_id, added: "New", removed: "Old"}
      }

      assert image_id == image.id
      assert_receive %Broadcast{event: "image:update"}
    end

    test "the uploader edits its own image, persisting the new description" do
      uploader = confirmed_user_fixture()
      image = image_fixture(user_id: uploader.id)

      assert {:ok, {updated, old_description}} =
               Images.update_image_description(actor(uploader), to_string(image.id), %{
                 "description" => "A fresh description"
               })

      assert updated.id == image.id
      assert updated.description == "A fresh description"
      assert Repo.reload!(image).description == "A fresh description"
      # NOTE: a never-described image carries the column default "", so the
      # returned prior value is the empty string, not nil.
      assert old_description == ""
      assert moderation_log_count() == 0
    end

    test "old_description carries the exact pre-update value" do
      uploader = confirmed_user_fixture()
      image = image_fixture(user_id: uploader.id, description: "Original text")

      assert {:ok, {_updated, old_description}} =
               Images.update_image_description(actor(uploader), to_string(image.id), %{
                 "description" => "Replacement text"
               })

      assert old_description == "Original text"
      assert Repo.reload!(image).description == "Replacement text"
    end

    test "a moderator edits another user's image" do
      moderator = moderator_user_fixture()
      uploader = confirmed_user_fixture()
      image = image_fixture(user_id: uploader.id)

      assert {:ok, {updated, _old}} =
               Images.update_image_description(actor(moderator), to_string(image.id), %{
                 "description" => "Moderator edit"
               })

      assert updated.description == "Moderator edit"
      assert Repo.reload!(image).description == "Moderator edit"
    end

    test "accepts an integer id" do
      uploader = confirmed_user_fixture()
      image = image_fixture(user_id: uploader.id)

      assert {:ok, {updated, _old}} =
               Images.update_image_description(actor(uploader), image.id, %{
                 "description" => "Via int"
               })

      assert updated.description == "Via int"
    end

    test "a banned actor is rejected before any loading, even with a garbage id" do
      # verify_write_access runs first, so a banned actor is {:error, :ban} even
      # against an id that could never parse.
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Images.update_image_description(actor, "not-a-number", %{"description" => "x"}) ==
               {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized before any loading" do
      actor = actor(confirmed_user_fixture(), fingerprint: nil)

      assert Images.update_image_description(actor, "not-a-number", %{"description" => "x"}) ==
               {:error, :unauthorized}
    end

    test "the uploader cannot edit when description editing is locked" do
      uploader = confirmed_user_fixture()
      image = image_fixture(user_id: uploader.id, description_editing_allowed: false)

      assert Images.update_image_description(actor(uploader), to_string(image.id), %{
               "description" => "blocked"
             }) == {:error, :unauthorized}

      assert Repo.reload!(image).description == image.description
    end

    test "a non-uploader regular user cannot edit the image" do
      owner = confirmed_user_fixture()
      other = confirmed_user_fixture()
      image = image_fixture(user_id: owner.id)

      assert Images.update_image_description(actor(other), to_string(image.id), %{
               "description" => "not mine"
             }) == {:error, :unauthorized}

      assert Repo.reload!(image).description == image.description
    end

    test "an anonymous actor with a fingerprint cannot edit the image" do
      # verify_write_access passes (fingerprint present, no ban) but the nil user
      # fails :edit_description, so this is unauthorized rather than a write.
      owner = confirmed_user_fixture()
      image = image_fixture(user_id: owner.id)

      assert Images.update_image_description(actor(), to_string(image.id), %{
               "description" => "anon"
             }) == {:error, :unauthorized}

      assert Repo.reload!(image).description == image.description
    end

    test "an over-long description is a changeset error with the image unchanged" do
      uploader = confirmed_user_fixture()
      image = image_fixture(user_id: uploader.id, description: "Original")
      too_long = String.duplicate("a", 50_001)

      assert {:error, %Ecto.Changeset{}} =
               Images.update_image_description(actor(uploader), to_string(image.id), %{
                 "description" => too_long
               })

      assert Repo.reload!(image).description == "Original"
    end

    test "an unknown well-formed id is not found for a non-admin actor" do
      # The image loads as nil and a regular user fails :edit_description on the
      # Missing image locators resolve to not-found before authorization.
      assert Images.update_image_description(actor(confirmed_user_fixture()), "2147483647", %{
               "description" => "x"
             }) == {:error, :not_found}
    end

    test "an unknown well-formed id is not found for an admin" do
      # Missing image locators resolve to not-found before authorization.
      # found.
      assert Images.update_image_description(actor(admin_user_fixture()), "2147483647", %{
               "description" => "x"
             }) == {:error, :not_found}
    end

    test "a non-castable id is not found for a valid actor" do
      assert Images.update_image_description(actor(confirmed_user_fixture()), "not-a-number", %{
               "description" => "x"
             }) == {:error, :not_found}
    end

    test "an out-of-range id is not found for a valid actor" do
      assert Images.update_image_description(
               actor(confirmed_user_fixture()),
               "99999999999999999999",
               %{
                 "description" => "x"
               }
             ) == {:error, :not_found}
    end
  end

  describe "delete_user_vote/3" do
    test "a moderator removes a target user's upvote, adjusting the score" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()
      image = image_fixture()
      baseline_score = Repo.reload!(image).score

      vote!(image, target, true)
      assert has_vote?(image, target)
      assert Repo.reload!(image).score == baseline_score + 1

      assert {:ok, returned} =
               Images.delete_user_vote(
                 actor(moderator),
                 to_string(image.id),
                 to_string(target.id)
               )

      assert returned.id == image.id
      refute has_vote?(image, target)
      assert Repo.reload!(image).score == baseline_score
    end

    test "removing an upvote writes an exact moderation log" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()
      image = image_fixture()
      vote!(image, target, true)

      assert {:ok, _} =
               Images.delete_user_vote(
                 actor(moderator),
                 to_string(image.id),
                 to_string(target.id)
               )

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.Tamper:create"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Deleted upvote by #{target.name} on image #{image.id}"
    end

    test "removing a downvote writes a log naming a downvote" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()
      image = image_fixture()
      vote!(image, target, false)

      assert {:ok, _} =
               Images.delete_user_vote(
                 actor(moderator),
                 to_string(image.id),
                 to_string(target.id)
               )

      refute has_vote?(image, target)

      log = only_moderation_log!()
      assert log.body == "Deleted downvote by #{target.name} on image #{image.id}"
    end

    test "removing a vote the user never cast still succeeds, logging a plain vote" do
      # With no upvote or downvote deleted, the type derivation falls through to
      # the neutral "vote".
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()
      image = image_fixture()
      refute has_vote?(image, target)

      assert {:ok, returned} =
               Images.delete_user_vote(
                 actor(moderator),
                 to_string(image.id),
                 to_string(target.id)
               )

      assert returned.id == image.id

      log = only_moderation_log!()
      assert log.body == "Deleted vote by #{target.name} on image #{image.id}"
    end

    test "accepts bare integer ids" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()
      image = image_fixture()
      vote!(image, target, true)

      assert {:ok, returned} = Images.delete_user_vote(actor(moderator), image.id, target.id)
      assert returned.id == image.id
      refute has_vote?(image, target)
    end

    test "a regular user is unauthorized and the vote is left intact" do
      # Image :tamper authorization runs before the user load, so a regular user
      # is denied without the vote being touched.
      user = confirmed_user_fixture()
      target = confirmed_user_fixture()
      image = image_fixture()
      vote!(image, target, true)

      assert Images.delete_user_vote(actor(user), to_string(image.id), to_string(target.id)) ==
               {:error, :unauthorized}

      assert has_vote?(image, target)
      assert moderation_log_count() == 0
    end

    test "a regular user with a garbage user_id is still unauthorized" do
      # The :tamper check precedes the user load, so a non-castable user id never
      # reaches the not-found path for an unprivileged actor.
      user = confirmed_user_fixture()
      image = image_fixture()

      assert Images.delete_user_vote(actor(user), to_string(image.id), "not-a-number") ==
               {:error, :unauthorized}

      assert moderation_log_count() == 0
    end

    test "an anonymous actor with a garbage user_id is unauthorized" do
      image = image_fixture()

      assert Images.delete_user_vote(actor(), to_string(image.id), "not-a-number") ==
               {:error, :unauthorized}

      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown user_id is not found and writes no log" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert Images.delete_user_vote(actor(moderator), to_string(image.id), "2147483647") ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "a moderator with a non-castable user_id is not found and writes no log" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert Images.delete_user_vote(actor(moderator), to_string(image.id), "not-a-number") ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "an unknown well-formed image_id is not found for a non-admin actor" do
      # Missing image locators resolve to not-found before authorization.
      user = confirmed_user_fixture()
      target = confirmed_user_fixture()

      assert Images.delete_user_vote(actor(user), "2147483647", to_string(target.id)) ==
               {:error, :not_found}
    end

    test "an unknown well-formed image_id is not found for an admin" do
      # Missing image locators resolve to not-found before authorization.
      admin = admin_user_fixture()
      target = confirmed_user_fixture()

      assert Images.delete_user_vote(actor(admin), "2147483647", to_string(target.id)) ==
               {:error, :not_found}
    end

    test "a non-castable image_id is not found" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()

      assert Images.delete_user_vote(actor(moderator), "not-a-number", to_string(target.id)) ==
               {:error, :not_found}
    end
  end

  describe "update_image_uploader/3" do
    test "a moderator reassigns the uploader, preloading the new user with awards" do
      moderator = moderator_user_fixture()
      owner = confirmed_user_fixture()
      new_owner = confirmed_user_fixture()
      image = image_fixture(user_id: owner.id)

      assert {:ok, updated} =
               Images.update_image_uploader(actor(moderator), to_string(image.id), %{
                 "username" => new_owner.name
               })

      assert updated.id == image.id
      assert Repo.reload!(image).user_id == new_owner.id

      assert Ecto.assoc_loaded?(updated.user)
      assert updated.user.id == new_owner.id
      assert Ecto.assoc_loaded?(updated.user.awards)
    end

    test "an admin reassigns the uploader" do
      admin = admin_user_fixture()
      owner = confirmed_user_fixture()
      new_owner = confirmed_user_fixture()
      image = image_fixture(user_id: owner.id)

      assert {:ok, _} =
               Images.update_image_uploader(actor(admin), to_string(image.id), %{
                 "username" => new_owner.name
               })

      assert Repo.reload!(image).user_id == new_owner.id
    end

    test "an empty username clears the uploader to nil" do
      moderator = moderator_user_fixture()
      owner = confirmed_user_fixture()
      image = image_fixture(user_id: owner.id)

      assert {:ok, updated} =
               Images.update_image_uploader(actor(moderator), to_string(image.id), %{
                 "username" => ""
               })

      assert updated.id == image.id
      assert Repo.reload!(image).user_id == nil
    end

    test "reassigning writes an exact moderation log" do
      moderator = moderator_user_fixture()
      new_owner = confirmed_user_fixture()
      image = image_fixture()

      assert {:ok, _} =
               Images.update_image_uploader(actor(moderator), to_string(image.id), %{
                 "username" => new_owner.name
               })

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.Uploader:update"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Changed uploader of image #{image.id}"
    end

    test "clearing the uploader also succeeds and writes the same log" do
      moderator = moderator_user_fixture()
      owner = confirmed_user_fixture()
      image = image_fixture(user_id: owner.id)

      assert {:ok, _} =
               Images.update_image_uploader(actor(moderator), to_string(image.id), %{
                 "username" => ""
               })

      log = only_moderation_log!()
      assert log.type == "Image.Uploader:update"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Changed uploader of image #{image.id}"
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      new_owner = confirmed_user_fixture()
      image = image_fixture()

      assert {:ok, updated} =
               Images.update_image_uploader(actor(moderator), image.id, %{
                 "username" => new_owner.name
               })

      assert updated.id == image.id
      assert Repo.reload!(image).user_id == new_owner.id
    end

    test "an unknown username is a changeset error with the image untouched and no log" do
      moderator = moderator_user_fixture()
      owner = confirmed_user_fixture()
      image = image_fixture(user_id: owner.id)

      assert {:error, %Ecto.Changeset{}} =
               Images.update_image_uploader(actor(moderator), to_string(image.id), %{
                 "username" => "no-such-user"
               })

      assert Repo.reload!(image).user_id == owner.id
      assert moderation_log_count() == 0
    end

    test "a regular user is unauthorized on a real image and params" do
      # Authorization on :identity_metadata runs before the load, so a regular user is
      # denied without the image ever being touched.
      user = confirmed_user_fixture()
      new_owner = confirmed_user_fixture()
      image = image_fixture()

      assert Images.update_image_uploader(actor(user), to_string(image.id), %{
               "username" => new_owner.name
             }) ==
               {:error, :unauthorized}

      assert moderation_log_count() == 0
    end

    test "a regular user with a garbage id and nil params is still unauthorized" do
      # The :identity_metadata authorization precedes the id parse and the params check,
      # so neither the not-found nor the invalid_params path is reached.
      user = confirmed_user_fixture()

      assert Images.update_image_uploader(actor(user), "not-a-number", nil) ==
               {:error, :unauthorized}

      assert moderation_log_count() == 0
    end

    test "an anonymous actor with a garbage id and nil params is unauthorized" do
      assert Images.update_image_uploader(actor(), "not-a-number", nil) == {:error, :unauthorized}
      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown well-formed image_id is not found and writes no log" do
      # Missing image locators resolve to not-found before authorization.
      # missing image is a plain not-found rather than unauthorized.
      moderator = moderator_user_fixture()
      new_owner = confirmed_user_fixture()

      assert Images.update_image_uploader(actor(moderator), "2147483647", %{
               "username" => new_owner.name
             }) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "a moderator with a non-castable image_id is not found" do
      moderator = moderator_user_fixture()
      new_owner = confirmed_user_fixture()

      assert Images.update_image_uploader(actor(moderator), "not-a-number", %{
               "username" => new_owner.name
             }) ==
               {:error, :not_found}
    end

    test "a moderator with an out-of-range image_id is not found" do
      moderator = moderator_user_fixture()
      new_owner = confirmed_user_fixture()

      assert Images.update_image_uploader(actor(moderator), "99999999999999999999", %{
               "username" => new_owner.name
             }) == {:error, :not_found}
    end
  end

  describe "create_image_user_hide/2" do
    test "a signed-in actor hides a visible image, recording a row and bumping the count" do
      user = confirmed_user_fixture()
      image = image_fixture()
      baseline = Repo.reload!(image).hides_count

      assert {:ok, hidden} = Images.create_image_user_hide(actor(user), to_string(image.id))
      assert hidden.id == image.id
      assert hidden.hides_count == baseline + 1
      assert image_hide_count(image, user) == 1
    end

    test "hiding again when already hidden leaves a single row" do
      # create appends a delete before the insert, so a repeat replaces the row
      # rather than stacking, and the count nets out unchanged.
      user = confirmed_user_fixture()
      image = image_fixture()
      baseline = Repo.reload!(image).hides_count

      assert {:ok, _} = Images.create_image_user_hide(actor(user), to_string(image.id))
      assert {:ok, again} = Images.create_image_user_hide(actor(user), to_string(image.id))

      assert again.hides_count == baseline + 1
      assert image_hide_count(image, user) == 1
    end

    test "accepts an integer id" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert {:ok, hidden} = Images.create_image_user_hide(actor(user), image.id)
      assert hidden.id == image.id
      assert image_hide_count(image, user) == 1
    end

    test "a banned actor is rejected before any loading, even with a garbage id" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Images.create_image_user_hide(actor, "not-a-number") == {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized before any loading" do
      actor = actor(confirmed_user_fixture(), fingerprint: nil)

      assert Images.create_image_user_hide(actor, "not-a-number") == {:error, :unauthorized}
    end

    test "a non-castable id is not found" do
      assert Images.create_image_user_hide(actor(confirmed_user_fixture()), "not-a-number") ==
               {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      assert Images.create_image_user_hide(
               actor(confirmed_user_fixture()),
               "99999999999999999999"
             ) ==
               {:error, :not_found}
    end

    test "an unknown well-formed id is not found for a regular actor" do
      # Missing image locators resolve to not-found before authorization.
      assert Images.create_image_user_hide(actor(confirmed_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "an unknown well-formed id is not found for a moderator" do
      assert Images.create_image_user_hide(actor(moderator_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "an unknown well-formed id is not found for an admin" do
      # Missing image locators resolve to not-found before authorization.
      assert Images.create_image_user_hide(actor(admin_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end
  end

  describe "delete_image_user_hide/2" do
    test "a signed-in actor unhides an image, removing the row and decrementing" do
      user = confirmed_user_fixture()
      image = image_fixture()
      baseline = Repo.reload!(image).hides_count
      {:ok, _} = Images.create_image_user_hide(actor(user), to_string(image.id))
      assert image_hide_count(image, user) == 1

      assert {:ok, unhidden} = Images.delete_image_user_hide(actor(user), to_string(image.id))
      assert unhidden.id == image.id
      assert unhidden.hides_count == baseline
      assert image_hide_count(image, user) == 0
    end

    test "unhiding when no row exists still succeeds" do
      user = confirmed_user_fixture()
      image = image_fixture()
      baseline = Repo.reload!(image).hides_count
      assert image_hide_count(image, user) == 0

      assert {:ok, unhidden} = Images.delete_image_user_hide(actor(user), to_string(image.id))
      assert unhidden.id == image.id
      assert unhidden.hides_count == baseline
      assert image_hide_count(image, user) == 0
    end

    test "accepts an integer id" do
      user = confirmed_user_fixture()
      image = image_fixture()
      {:ok, _} = Images.create_image_user_hide(actor(user), image.id)

      assert {:ok, unhidden} = Images.delete_image_user_hide(actor(user), image.id)
      assert unhidden.id == image.id
      assert image_hide_count(image, user) == 0
    end

    test "a banned actor is rejected before any loading, even with a garbage id" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Images.delete_image_user_hide(actor, "not-a-number") == {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized before any loading" do
      actor = actor(confirmed_user_fixture(), fingerprint: nil)

      assert Images.delete_image_user_hide(actor, "not-a-number") == {:error, :unauthorized}
    end

    test "a non-castable id is not found" do
      assert Images.delete_image_user_hide(actor(confirmed_user_fixture()), "not-a-number") ==
               {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      assert Images.delete_image_user_hide(
               actor(confirmed_user_fixture()),
               "99999999999999999999"
             ) ==
               {:error, :not_found}
    end

    test "an unknown well-formed id is not found for a regular actor" do
      assert Images.delete_image_user_hide(actor(confirmed_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "an unknown well-formed id is not found for an admin" do
      assert Images.delete_image_user_hide(actor(admin_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end
  end

  describe "image interaction prerequisites" do
    test "normalizes write-access and image-loading failures in the owning actions" do
      assert Images.create_image_fave(
               actor(confirmed_user_fixture(), ban: @ban),
               "not-a-number"
             ) == {:error, :ban}

      assert Images.create_image_fave(
               actor(confirmed_user_fixture(), fingerprint: nil),
               "not-a-number"
             ) == {:error, :unauthorized}

      assert Images.create_image_fave(actor(confirmed_user_fixture()), "not-a-number") ==
               {:error, :not_found}

      assert Images.create_image_fave(actor(confirmed_user_fixture()), "2147483647") ==
               {:error, :not_found}

      assert Images.create_image_fave(actor(admin_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "the Images-owned service enforces complex forced filters" do
      image = image_fixture()
      other_image = image_fixture()

      {user, _filter} =
        force_filter(confirmed_user_fixture(), hidden_complex_str: "id:#{image.id}")

      assert Images.verify_forced_filter_access(actor(user), image) ==
               {:error, :forced_filter}

      assert Images.verify_forced_filter_access(actor(user), other_image) == :ok
    end

    test "fave and vote creates and deletes all enforce forced hidden tags" do
      image = image_fixture(tags: "safe")
      [tag] = image.tags
      user = confirmed_user_fixture()

      fave!(image, user)
      vote!(image, user, true)
      {user, _filter} = force_filter(user, hidden_tag_ids: [tag.id])
      actor = actor(user)

      assert Images.create_image_fave(actor, image.id) == {:error, :forced_filter}
      assert Images.delete_image_fave(actor, image.id) == {:error, :forced_filter}
      assert Images.create_image_vote(actor, image.id, %{up: false}) == {:error, :forced_filter}
      assert Images.delete_image_vote(actor, image.id) == {:error, :forced_filter}

      assert fave_count(image, user) == 1
      assert %ImageVote{up: true} = vote_row(image, user)
    end
  end

  describe "create_image_fave/2" do
    test "records a fave and an implicit upvote, bumping faves_count and score" do
      user = confirmed_user_fixture()
      image = image_fixture()
      base_score = Repo.reload!(image).score
      base_faves = Repo.reload!(image).faves_count

      assert {:ok, faved} = Images.create_image_fave(actor(user), image.id)
      assert faved.id == image.id
      assert faved.faves_count == base_faves + 1
      assert faved.score == base_score + 1

      assert fave_count(image, user) == 1
      assert %ImageVote{up: true} = vote_row(image, user)
    end

    test "replaces an existing downvote with the fave's upvote" do
      user = confirmed_user_fixture()
      image = image_fixture()
      base_score = Repo.reload!(image).score

      vote!(image, user, false)
      assert %ImageVote{up: false} = vote_row(image, user)

      assert {:ok, faved} = Images.create_image_fave(actor(user), image.id)
      assert %ImageVote{up: true} = vote_row(image, user)
      assert faved.score == base_score + 1
    end

    test "faving again when already faved stays at a single fave row" do
      user = confirmed_user_fixture()
      image = image_fixture()
      base_faves = Repo.reload!(image).faves_count

      assert {:ok, _} = Images.create_image_fave(actor(user), image.id)
      assert {:ok, again} = Images.create_image_fave(actor(user), image.id)

      assert fave_count(image, user) == 1
      assert again.faves_count == base_faves + 1
    end
  end

  describe "delete_image_fave/2" do
    test "removes the fave but keeps the upvote, dropping faves_count and leaving score" do
      user = confirmed_user_fixture()
      image = image_fixture()
      base_score = Repo.reload!(image).score
      base_faves = Repo.reload!(image).faves_count

      {:ok, faved} = Images.create_image_fave(actor(user), image.id)
      assert fave_count(image, user) == 1

      assert {:ok, unfaved} = Images.delete_image_fave(actor(user), image.id)
      assert unfaved.id == image.id
      assert fave_count(image, user) == 0
      assert unfaved.faves_count == base_faves
      # The implicit upvote survives, so the score stays where the fave put it.
      assert unfaved.score == base_score + 1
      assert %ImageVote{up: true} = vote_row(image, user)
      assert faved.score == unfaved.score
    end

    test "unfaving when no fave exists still succeeds" do
      user = confirmed_user_fixture()
      image = image_fixture()
      base_faves = Repo.reload!(image).faves_count
      assert fave_count(image, user) == 0

      assert {:ok, unfaved} = Images.delete_image_fave(actor(user), image.id)
      assert unfaved.id == image.id
      assert fave_count(image, user) == 0
      assert unfaved.faves_count == base_faves
    end
  end

  describe "create_image_vote/3" do
    test "an upvote records the row and bumps score and upvotes_count" do
      user = confirmed_user_fixture()
      image = image_fixture()
      base_score = Repo.reload!(image).score
      base_upvotes = Repo.reload!(image).upvotes_count

      assert {:ok, voted} = Images.create_image_vote(actor(user), image.id, %{up: true})
      assert voted.id == image.id
      assert voted.score == base_score + 1
      assert voted.upvotes_count == base_upvotes + 1
      assert %ImageVote{up: true} = vote_row(image, user)
    end

    test "a downvote records the row and drops score" do
      user = confirmed_user_fixture()
      image = image_fixture()
      base_score = Repo.reload!(image).score
      base_downvotes = Repo.reload!(image).downvotes_count

      assert {:ok, voted} = Images.create_image_vote(actor(user), image.id, %{up: false})
      assert voted.score == base_score - 1
      assert voted.downvotes_count == base_downvotes + 1
      assert %ImageVote{up: false} = vote_row(image, user)
    end

    test "revoting flips an existing downvote to an upvote in a single row" do
      # From the downvoted state the score swings up by two (the downvote is
      # removed and an upvote added), ending one above the baseline.
      user = confirmed_user_fixture()
      image = image_fixture()
      base_score = Repo.reload!(image).score

      vote!(image, user, false)
      assert %ImageVote{up: false} = vote_row(image, user)
      assert Repo.reload!(image).score == base_score - 1

      assert {:ok, voted} = Images.create_image_vote(actor(user), image.id, %{up: true})
      # get_by raises on more than one row, so a returned struct confirms a
      # single vote row survived the flip.
      assert %ImageVote{up: true} = vote_row(image, user)
      assert voted.score == base_score + 1
    end
  end

  describe "delete_image_vote/2" do
    test "removing an upvote restores the score" do
      user = confirmed_user_fixture()
      image = image_fixture()
      base_score = Repo.reload!(image).score
      {:ok, _} = Images.create_image_vote(actor(user), image.id, %{up: true})

      assert {:ok, unvoted} = Images.delete_image_vote(actor(user), image.id)
      assert unvoted.id == image.id
      assert vote_row(image, user) == nil
      assert unvoted.score == base_score
    end

    test "removing a downvote restores the score" do
      user = confirmed_user_fixture()
      image = image_fixture()
      base_score = Repo.reload!(image).score
      vote!(image, user, false)

      assert {:ok, unvoted} = Images.delete_image_vote(actor(user), image.id)
      assert vote_row(image, user) == nil
      assert unvoted.score == base_score
    end

    test "unvoting when no vote exists still succeeds" do
      user = confirmed_user_fixture()
      image = image_fixture()
      base_score = Repo.reload!(image).score
      refute has_vote?(image, user)

      assert {:ok, unvoted} = Images.delete_image_vote(actor(user), image.id)
      assert unvoted.id == image.id
      assert unvoted.score == base_score
      refute has_vote?(image, user)
    end
  end

  describe "create_image_hide/3" do
    test "a moderator hides the image, persisting the reason" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, hidden} =
               Images.create_image_hide(actor(moderator), to_string(image.id), %{
                 "deletion_reason" => "Rule #0"
               })

      assert hidden.id == image.id
      assert hidden.hidden_from_users

      reloaded = Repo.reload!(image)
      assert reloaded.hidden_from_users
      assert reloaded.deletion_reason == "Rule #0"
    end

    test "an admin hides the image" do
      admin = admin_user_fixture()
      image = image_fixture()

      assert {:ok, _} =
               Images.create_image_hide(actor(admin), to_string(image.id), %{
                 "deletion_reason" => "Rule #0"
               })

      assert Repo.reload!(image).hidden_from_users
    end

    test "hiding writes an exact moderation log" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, _} =
               Images.create_image_hide(actor(moderator), to_string(image.id), %{
                 "deletion_reason" => "Rule #0"
               })

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.Delete:create"
      assert log.subject_path == "/images/#{image.id}"
      assert log.body == "Deleted image #{image.id} (Rule #0)"
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:ok, hidden} =
               Images.create_image_hide(actor(moderator), image.id, %{
                 "deletion_reason" => "Rule #0"
               })

      assert hidden.id == image.id
    end

    test "a blank reason fails with the image left visible and no log" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Images.create_image_hide(actor(moderator), to_string(image.id), %{
                 "deletion_reason" => ""
               })

      refute Repo.reload!(image).hidden_from_users
      assert moderation_log_count() == 0
    end

    test "a regular user cannot hide the image and it stays visible" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert Images.create_image_hide(actor(user), to_string(image.id), %{
               "deletion_reason" => "Rule #0"
             }) ==
               {:error, :unauthorized}

      refute Repo.reload!(image).hidden_from_users
      assert moderation_log_count() == 0
    end

    test "an anonymous actor cannot hide the image" do
      image = image_fixture()

      assert Images.create_image_hide(actor(), to_string(image.id), %{
               "deletion_reason" => "Rule #0"
             }) ==
               {:error, :unauthorized}

      refute Repo.reload!(image).hidden_from_users
      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown well-formed id is not found and writes no log" do
      moderator = moderator_user_fixture()

      assert Images.create_image_hide(actor(moderator), "2147483647", %{
               "deletion_reason" => "Rule #0"
             }) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "an admin with an unknown well-formed id is not found and writes no log" do
      admin = admin_user_fixture()

      assert Images.create_image_hide(actor(admin), "2147483647", %{
               "deletion_reason" => "Rule #0"
             }) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.create_image_hide(actor(moderator), "not-a-number", %{
               "deletion_reason" => "Rule #0"
             }) ==
               {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      moderator = moderator_user_fixture()

      assert Images.create_image_hide(actor(moderator), "99999999999999999999", %{
               "deletion_reason" => "Rule #0"
             }) == {:error, :not_found}
    end
  end

  describe "update_image_hide/3" do
    test "a moderator updates the reason on a hidden image" do
      moderator = moderator_user_fixture()
      hidden = hidden_image_fixture("Original reason")

      assert {:ok, updated} =
               Images.update_image_hide(actor(moderator), to_string(hidden.id), %{
                 "deletion_reason" => "Better reason"
               })

      assert updated.id == hidden.id
      assert Repo.reload!(hidden).deletion_reason == "Better reason"
    end

    test "updating the reason writes an exact moderation log with the new reason" do
      moderator = moderator_user_fixture()
      hidden = hidden_image_fixture("Original reason")

      assert {:ok, _} =
               Images.update_image_hide(actor(moderator), to_string(hidden.id), %{
                 "deletion_reason" => "Better reason"
               })

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.Delete:update"
      assert log.subject_path == "/images/#{hidden.id}"
      assert log.body == "Changed deletion reason of #{hidden.id} (Better reason)"
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      hidden = hidden_image_fixture()

      assert {:ok, updated} =
               Images.update_image_hide(actor(moderator), hidden.id, %{
                 "deletion_reason" => "New"
               })

      assert updated.id == hidden.id
    end

    test "a visible image is fails with no log" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Images.update_image_hide(actor(moderator), to_string(image.id), %{
                 "deletion_reason" => "New"
               })

      assert moderation_log_count() == 0
    end

    test "a regular user on a visible image is unauthorized, not not_deleted" do
      # Authorization runs before the hidden-state check, so a regular user fails
      # :hide and never reaches the not_deleted branch.
      user = confirmed_user_fixture()
      image = image_fixture()

      assert Images.update_image_hide(actor(user), to_string(image.id), %{
               "deletion_reason" => "New"
             }) ==
               {:error, :unauthorized}

      assert moderation_log_count() == 0
    end

    test "a blank reason on a hidden image is a changeset error with the reason unchanged" do
      moderator = moderator_user_fixture()
      hidden = hidden_image_fixture("Keep me")

      assert {:error, %Ecto.Changeset{}} =
               Images.update_image_hide(actor(moderator), to_string(hidden.id), %{
                 "deletion_reason" => ""
               })

      assert Repo.reload!(hidden).deletion_reason == "Keep me"
      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown well-formed id is not found and writes no log" do
      moderator = moderator_user_fixture()

      assert Images.update_image_hide(actor(moderator), "2147483647", %{
               "deletion_reason" => "New"
             }) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "an admin with an unknown well-formed id is not found and writes no log" do
      admin = admin_user_fixture()

      assert Images.update_image_hide(actor(admin), "2147483647", %{"deletion_reason" => "New"}) ==
               {:error, :not_found}

      assert moderation_log_count() == 0
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_image_hide(actor(moderator), "not-a-number", %{
               "deletion_reason" => "New"
             }) ==
               {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      moderator = moderator_user_fixture()

      assert Images.update_image_hide(actor(moderator), "99999999999999999999", %{
               "deletion_reason" => "New"
             }) == {:error, :not_found}
    end
  end

  describe "delete_image_hide/2" do
    test "a moderator restores a hidden image" do
      moderator = moderator_user_fixture()
      hidden = hidden_image_fixture()

      assert {:ok, restored} = Images.delete_image_hide(actor(moderator), to_string(hidden.id))
      assert restored.id == hidden.id
      refute restored.hidden_from_users
      refute Repo.reload!(hidden).hidden_from_users
    end

    test "an admin restores a hidden image" do
      admin = admin_user_fixture()
      hidden = hidden_image_fixture()

      assert {:ok, _} = Images.delete_image_hide(actor(admin), to_string(hidden.id))
      refute Repo.reload!(hidden).hidden_from_users
    end

    test "restoring writes an exact moderation log" do
      moderator = moderator_user_fixture()
      hidden = hidden_image_fixture()

      assert {:ok, _} = Images.delete_image_hide(actor(moderator), to_string(hidden.id))

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Image.Delete:delete"
      assert log.subject_path == "/images/#{hidden.id}"
      assert log.body == "Restored image #{hidden.id}"
    end

    test "restoring an already-visible image fails and writes no log" do
      moderator = moderator_user_fixture()
      image = image_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Images.delete_image_hide(actor(moderator), to_string(image.id))

      refute Repo.reload!(image).hidden_from_users
      assert moderation_log_count() == 0
    end

    test "accepts an integer id" do
      moderator = moderator_user_fixture()
      hidden = hidden_image_fixture()

      assert {:ok, restored} = Images.delete_image_hide(actor(moderator), hidden.id)
      assert restored.id == hidden.id
    end

    test "a regular user cannot restore a hidden image and it stays hidden" do
      user = confirmed_user_fixture()
      hidden = hidden_image_fixture()

      assert Images.delete_image_hide(actor(user), to_string(hidden.id)) ==
               {:error, :unauthorized}

      assert Repo.reload!(hidden).hidden_from_users
      assert moderation_log_count() == 0
    end

    test "an anonymous actor cannot restore a hidden image" do
      hidden = hidden_image_fixture()

      assert Images.delete_image_hide(actor(), to_string(hidden.id)) == {:error, :unauthorized}
      assert Repo.reload!(hidden).hidden_from_users
      assert moderation_log_count() == 0
    end

    test "a moderator with an unknown well-formed id is not found and writes no log" do
      moderator = moderator_user_fixture()

      assert Images.delete_image_hide(actor(moderator), "2147483647") == {:error, :not_found}
      assert moderation_log_count() == 0
    end

    test "an admin with an unknown well-formed id is not found and writes no log" do
      admin = admin_user_fixture()

      assert Images.delete_image_hide(actor(admin), "2147483647") == {:error, :not_found}
      assert moderation_log_count() == 0
    end

    test "a non-castable id is not found" do
      moderator = moderator_user_fixture()

      assert Images.delete_image_hide(actor(moderator), "not-a-number") == {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      moderator = moderator_user_fixture()

      assert Images.delete_image_hide(actor(moderator), "99999999999999999999") ==
               {:error, :not_found}
    end
  end

  describe "update_image_sources/3" do
    test "broadcasts source and rendered image updates after persistence" do
      user = confirmed_user_fixture()
      image = image_fixture()
      :ok = Endpoint.subscribe("firehose")

      assert {:ok, _result} =
               Images.update_image_sources(
                 actor(user),
                 image.id,
                 add_source_attrs("https://example.test/source")
               )

      assert_receive %Broadcast{
        event: "image:source_update",
        payload: %{image_id: image_id}
      }

      assert image_id == image.id
      assert_receive %Broadcast{event: "image:update"}
    end

    test "a signed-in actor adds a source, recording an attributed change and bumping stats" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert {:ok, result} =
               Images.update_image_sources(
                 actor(user),
                 to_string(image.id),
                 add_source_attrs("https://example.com/art")
               )

      assert result.image.id == image.id
      assert result.source_change_count == 1

      change = Repo.one(from s in SourceChange, where: s.image_id == ^image.id)
      assert change.source_url == "https://example.com/art"
      assert change.user_id == user.id
      assert change.added == true

      assert Repo.reload!(user).metadata_updates_count == 1
    end

    test "an anonymous fingerprinted actor records a change with no user" do
      image = image_fixture()

      assert {:ok, _result} =
               Images.update_image_sources(
                 actor(nil, ip: random_ip()),
                 to_string(image.id),
                 add_source_attrs("https://example.com/anon")
               )

      change = Repo.one(from s in SourceChange, where: s.image_id == ^image.id)
      assert change.source_url == "https://example.com/anon"
      assert change.user_id == nil
    end

    test "accepts an integer id" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert {:ok, result} =
               Images.update_image_sources(
                 actor(user),
                 image.id,
                 add_source_attrs("https://example.com/i")
               )

      assert result.image.id == image.id
    end

    test "a banned actor is rejected before any loading, even with a garbage id" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Images.update_image_sources(
               actor,
               "not-a-number",
               add_source_attrs("https://x.test")
             ) ==
               {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized before any loading" do
      actor = actor(confirmed_user_fixture(), fingerprint: nil)

      assert Images.update_image_sources(
               actor,
               "not-a-number",
               add_source_attrs("https://x.test")
             ) ==
               {:error, :unauthorized}
    end

    test "a hidden image is unauthorized and records no change" do
      # edit_metadata requires a non-hidden image, so a hidden one fails
      # authorization for a signed-in actor.
      user = confirmed_user_fixture()
      hidden = hidden_image_fixture()

      assert Images.update_image_sources(
               actor(user),
               to_string(hidden.id),
               add_source_attrs("https://x.test")
             ) == {:error, :unauthorized}

      assert source_change_row_count(hidden) == 0
    end

    test "more than 15 sources is a changeset error with no change recorded" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Images.update_image_sources(
                 actor(user),
                 to_string(image.id),
                 many_source_attrs(16)
               )

      assert source_change_row_count(image) == 0
    end

    test "an invalid source URL returns an image-backed changeset" do
      user = confirmed_user_fixture()
      image = image_fixture(sources: ["https://example.com/existing"])

      assert {:error, %Ecto.Changeset{data: %Image{} = changeset_image} = changeset} =
               Images.update_image_sources(
                 actor(user),
                 image.id,
                 %{
                   "old_sources" => %{},
                   "sources" => %{"0" => %{"source" => "not-a-url"}}
                 }
               )

      assert changeset_image.id == image.id
      source_changeset = Enum.find(get_change(changeset, :sources), &(not &1.valid?))
      assert %Ecto.Changeset{} = source_changeset
      assert "has invalid format" in errors_on(source_changeset).source
      assert source_urls(image) == ["https://example.com/existing"]
      assert source_change_row_count(image) == 0
    end

    test "an unknown well-formed id is not found for a regular actor" do
      # The image loads as nil and a regular actor fails :edit_metadata on the nil
      # Missing image locators resolve to not-found before authorization.
      assert Images.update_image_sources(
               actor(confirmed_user_fixture()),
               "2147483647",
               add_source_attrs("https://x.test")
             ) == {:error, :not_found}
    end

    test "an unknown well-formed id is not found for an admin" do
      # Missing image locators resolve to not-found before authorization.
      assert Images.update_image_sources(
               actor(admin_user_fixture()),
               "2147483647",
               add_source_attrs("https://x.test")
             ) == {:error, :not_found}
    end

    test "a non-castable id is not found" do
      assert Images.update_image_sources(
               actor(confirmed_user_fixture()),
               "not-a-number",
               add_source_attrs("https://x.test")
             ) == {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      assert Images.update_image_sources(
               actor(confirmed_user_fixture()),
               "99999999999999999999",
               add_source_attrs("https://x.test")
             ) == {:error, :not_found}
    end

    test "an over-limit actor is rate limited and records no source change" do
      # The :source_update counter is primed past the limit, so the rate check
      # (after write-access, before the id parse and load) refuses the write.
      image = image_fixture()
      actor = actor(confirmed_user_fixture())
      exceed_rate_limit(actor, :source_update)

      assert Images.update_image_sources(
               actor,
               to_string(image.id),
               add_source_attrs("https://x.test")
             ) == {:error, :rate_limited}

      assert source_change_row_count(image) == 0
    end

    test "a successful update records the counter" do
      image = image_fixture()
      actor = actor(confirmed_user_fixture())
      track_rate_limit(actor, :source_update)

      assert {:ok, _result} =
               Images.update_image_sources(
                 actor,
                 to_string(image.id),
                 add_source_attrs("https://x.test")
               )

      assert rate_limit_count(actor, :source_update) == "1"
    end

    test "a non-castable id does not consume the rate limit" do
      actor = actor(confirmed_user_fixture())
      exceed_rate_limit(actor, :source_update)

      assert Images.update_image_sources(
               actor,
               "not-a-number",
               add_source_attrs("https://x.test")
             ) ==
               {:error, :not_found}
    end
  end

  describe "update_image_tags/3" do
    setup do
      # The shared attribution fixture's anonymous identity (i:<ip>) is not rolled
      # back by the SQL sandbox and accumulates across runs, so clear it before
      # each test. Signed-in tests use fresh users, whose u:<id> bucket starts
      # empty on its own.
      reset_tag_change_limits()
      :ok
    end

    test "broadcasts tag and rendered image updates after persistence" do
      user = confirmed_user_fixture()
      image = image_fixture()
      :ok = Endpoint.subscribe("firehose")

      assert {:ok, _result} =
               Images.update_image_tags(
                 actor(user),
                 image.id,
                 tag_attrs("safe", "safe, broadcast tag, another broadcast tag")
               )

      assert_receive %Broadcast{
        event: "image:tag_update",
        payload: %{image_id: image_id, added: added}
      }

      assert image_id == image.id
      assert Enum.sort(added) == ["another broadcast tag", "broadcast tag"]
      assert_receive %Broadcast{event: "image:update"}
    end

    test "a signed-in actor changes tags, recording an attributed change and bumping stats" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert {:ok, result} =
               Images.update_image_tags(
                 actor(user),
                 to_string(image.id),
                 tag_attrs("safe", "safe, added test tag, other added tag")
               )

      assert result.image.id == image.id
      assert Enum.find(result.image.tags, &(&1.name == "added test tag")).images_count == 1
      assert Enum.find(result.image.tags, &(&1.name == "other added tag")).images_count == 1
      assert result.tag_change_count >= 1
      assert result.tag_change_tag_count >= 1

      assert tag_names(image) == ["added test tag", "other added tag", "safe"]

      change = Repo.one(from tc in TagChange, where: tc.image_id == ^image.id)
      assert change.user_id == user.id

      assert Repo.reload!(user).metadata_updates_count == 1
    end

    test "an anonymous fingerprinted actor records a change with no user" do
      image = image_fixture()

      assert {:ok, _result} =
               Images.update_image_tags(
                 actor(nil, ip: random_ip()),
                 to_string(image.id),
                 tag_attrs("safe", "safe, added test tag, other added tag")
               )

      change = Repo.one(from tc in TagChange, where: tc.image_id == ^image.id)
      assert change.user_id == nil
    end

    test "accepts an integer id" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert {:ok, result} =
               Images.update_image_tags(
                 actor(user),
                 image.id,
                 tag_attrs("safe", "safe, added test tag, other added tag")
               )

      assert result.image.id == image.id
    end

    test "a banned actor is rejected before any loading, even with a garbage id" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Images.update_image_tags(actor, "not-a-number", tag_attrs("safe", "safe, a, b")) ==
               {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized before any loading" do
      actor = actor(confirmed_user_fixture(), fingerprint: nil)

      assert Images.update_image_tags(actor, "not-a-number", tag_attrs("safe", "safe, a, b")) ==
               {:error, :unauthorized}
    end

    test "an image with tag editing disabled is unauthorized and records no change" do
      user = confirmed_user_fixture()
      image = image_fixture(tag_editing_allowed: false)

      assert Images.update_image_tags(
               actor(user),
               to_string(image.id),
               tag_attrs("safe", "safe, added test tag, other added tag")
             ) == {:error, :unauthorized}

      refute Repo.exists?(from tc in TagChange, where: tc.image_id == ^image.id)
    end

    test "reducing below the minimum tag count is a changeset error with tags unchanged" do
      user = confirmed_user_fixture()
      image = image_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Images.update_image_tags(
                 actor(user),
                 to_string(image.id),
                 tag_attrs("safe", "safe, one more")
               )

      assert tag_names(image) == ["safe"]
      refute Repo.exists?(from tc in TagChange, where: tc.image_id == ^image.id)
    end

    test "exceeding the tag-change rate limit rolls the transaction back" do
      user = confirmed_user_fixture()
      image = image_fixture()
      ip = %Postgrex.INET{address: {203, 0, 113, 1}, netmask: 32}

      # Fill the user's tag bucket to the 50-change limit so the next multi-tag
      # update trips check_limits. The counter carries a 10-minute TTL that the
      # SQL sandbox does not roll back, so clear it afterward.
      :ok = Limits.record_action(user, ip, 50, 0)
      on_exit(fn -> reset_tag_change_limits(user: user, ip: ip) end)

      assert Images.update_image_tags(
               actor(user),
               to_string(image.id),
               tag_attrs("safe", "safe, added test tag, other added tag")
             ) == {:error, :rate_limited}

      assert tag_names(image) == ["safe"]
      refute Repo.exists?(from tc in TagChange, where: tc.image_id == ^image.id)
    end

    test "an unknown well-formed id is not found for a regular actor" do
      # The image loads as nil and a regular actor fails :edit_metadata on the nil
      # Missing image locators resolve to not-found before authorization.
      assert Images.update_image_tags(
               actor(confirmed_user_fixture()),
               "2147483647",
               tag_attrs("safe", "safe, a, b")
             ) == {:error, :not_found}
    end

    test "an unknown well-formed id is not found for an admin" do
      # Missing image locators resolve to not-found before authorization.
      assert Images.update_image_tags(
               actor(admin_user_fixture()),
               "2147483647",
               tag_attrs("safe", "safe, a, b")
             ) == {:error, :not_found}
    end

    test "a non-castable id is not found" do
      assert Images.update_image_tags(
               actor(confirmed_user_fixture()),
               "not-a-number",
               tag_attrs("safe", "safe, a, b")
             ) == {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      assert Images.update_image_tags(
               actor(confirmed_user_fixture()),
               "99999999999999999999",
               tag_attrs("safe", "safe, a, b")
             ) == {:error, :not_found}
    end

    test "an over-limit once-per-window actor is rate limited and records no change" do
      # This is the new once-per-window counter (rl:tag_update:*), distinct from
      # the tag-count limiter (rltcn:/rltcr:) the test above exercises. Priming it
      # over the limit makes the rate check (after write-access, before the load)
      # refuse the write.
      image = image_fixture()
      actor = actor(confirmed_user_fixture())
      exceed_rate_limit(actor, :tag_update)

      assert Images.update_image_tags(
               actor,
               to_string(image.id),
               tag_attrs("safe", "safe, added test tag, other added tag")
             ) == {:error, :rate_limited}

      assert tag_names(image) == ["safe"]
      refute Repo.exists?(from tc in TagChange, where: tc.image_id == ^image.id)
    end

    test "a successful update records the once-per-window counter" do
      image = image_fixture()
      actor = actor(confirmed_user_fixture())
      track_rate_limit(actor, :tag_update)

      assert {:ok, _result} =
               Images.update_image_tags(
                 actor,
                 to_string(image.id),
                 tag_attrs("safe", "safe, added test tag, other added tag")
               )

      assert rate_limit_count(actor, :tag_update) == "1"
    end

    test "a non-castable id does not consume the rate limit" do
      actor = actor(confirmed_user_fixture())
      exceed_rate_limit(actor, :tag_update)

      assert Images.update_image_tags(actor, "not-a-number", tag_attrs("safe", "safe, a, b")) ==
               {:error, :not_found}
    end
  end

  # Records one tag change against `image` (adding two tags), returning the
  # image. Produces a single tag_changes row carrying two tag_change_tags.
  defp record_tag_change(image) do
    user = confirmed_user_fixture()
    reset_tag_change_limits()

    {:ok, _} =
      Images.update_image_tags(
        actor(user),
        to_string(image.id),
        tag_attrs("safe", "safe, alpha, beta")
      )

    image
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

  defp index_scope do
    Scope.new(default_filter(), %{page_number: 1, page_size: 25})
  end

  defp search_scope(params) do
    Scope.new(default_filter(), %{page_number: 1, page_size: 25}, params)
  end

  defp minutes_ago(minutes) do
    DateTime.utc_now()
    |> DateTime.add(-minutes * 60, :second)
    |> DateTime.truncate(:second)
  end

  describe "show_image/2" do
    test "an anonymous viewer loads a visible image with zero change counts" do
      image = image_fixture()

      assert {:ok, loaded} = Images.show_image(actor(), to_string(image.id))
      assert loaded.id == image.id
      assert loaded.tag_change_count == 0
      assert loaded.tag_change_tag_count == 0
      assert loaded.source_change_count == 0
    end

    test "the change counts reflect recorded tag and source changes" do
      image = image_fixture()
      record_tag_change(image)
      source_change_fixture(image)
      source_change_fixture(image)

      assert {:ok, loaded} = Images.show_image(actor(), to_string(image.id))
      assert loaded.tag_change_count == 1
      assert loaded.tag_change_tag_count == 2
      assert loaded.source_change_count == 2
    end

    test "the show preloads are populated on the loaded image" do
      image = image_fixture(sources: ["https://example.com/a"])

      assert {:ok, loaded} = Images.show_image(actor(), to_string(image.id))
      assert Ecto.assoc_loaded?(loaded.tags)
      assert Ecto.assoc_loaded?(loaded.sources)
      assert Ecto.assoc_loaded?(loaded.locked_tags)
    end

    test "accepts an integer id" do
      image = image_fixture()

      assert {:ok, loaded} = Images.show_image(actor(), image.id)
      assert loaded.id == image.id
    end

    test "a hidden image is returned to an anonymous viewer" do
      image = image_fixture(hidden_from_users: true)

      assert {:ok, %Image{}} = Images.show_image(actor(), to_string(image.id))
    end

    test "a hidden duplicate is redirected for an anonymous viewer" do
      # A merged image is hidden from users; a viewer who cannot :show the
      # hidden image is redirected to its duplicate rather than shown the notice.
      original = image_fixture()
      duplicate = image_fixture(duplicate_id: original.id, hidden_from_users: true)

      assert {:duplicate_of, target_id} =
               Images.show_image(actor(), to_string(duplicate.id))

      assert target_id == original.id
    end

    test "a non-hidden duplicate is shown to an anonymous viewer" do
      # The duplicate branch only fires when the viewer cannot :show the image;
      # a duplicate that is not hidden is still viewable, so it loads normally.
      original = image_fixture()
      duplicate = image_fixture(duplicate_id: original.id)

      assert {:ok, loaded} = Images.show_image(actor(), to_string(duplicate.id))

      assert loaded.id == duplicate.id
    end

    test "a hidden duplicate loads normally for a moderator who can show it" do
      moderator = moderator_user_fixture()
      original = image_fixture()
      duplicate = image_fixture(duplicate_id: original.id, hidden_from_users: true)

      assert {:ok, loaded} =
               Images.show_image(actor(moderator), to_string(duplicate.id))

      assert loaded.id == duplicate.id
    end

    test "an unknown well-formed id is not found for an anonymous viewer" do
      # Missing images are resolved before the viewer's :show permission.
      assert Images.show_image(actor(), "2147483647") == {:error, :not_found}
    end

    test "an unknown well-formed id is not found for an admin" do
      assert Images.show_image(actor(admin_user_fixture()), "2147483647") ==
               {:error, :not_found}
    end

    test "a non-castable id is not found" do
      assert Images.show_image(actor(), "not-a-number") == {:error, :not_found}
    end

    test "an out-of-range id is not found" do
      assert Images.show_image(actor(), "99999999999999999999") == {:error, :not_found}
    end
  end

  describe "show_image_page/3" do
    test "assembles the page struct for a signed-in viewer" do
      user = confirmed_user_fixture()
      image = image_fixture()

      page = Images.show_image_page(actor(user), image, page: 1, page_size: 25)

      assert %ImagePage{} = page
      assert page.image.id == image.id
      assert %Scrivener.Page{} = page.comments
      assert is_boolean(page.watching)
      assert is_list(page.user_galleries)
      assert is_list(page.interactions)
      assert %Ecto.Changeset{} = page.comment_changeset
      assert %Ecto.Changeset{} = page.tag_changeset
      assert %Ecto.Changeset{} = page.source_changeset
      refute page.description_changeset
      refute page.hide_changeset
      refute page.file_changeset
      refute page.feature_changeset
      refute page.repair_changeset
      refute page.hash_changeset
      refute page.uploader_changeset
    end

    test "assembles the page struct for an anonymous viewer" do
      image = image_fixture()

      page = Images.show_image_page(actor(), image, page: 1, page_size: 25)

      assert %ImagePage{} = page
      refute page.watching
      assert page.user_galleries == []
      assert page.interactions == []
      refute page.can_interact
    end

    test "a viewer whose first request has no fingerprint still gets write controls" do
      image = image_fixture()

      page =
        Images.show_image_page(actor(moderator_user_fixture(), fingerprint: nil), image,
          page: 1,
          page_size: 25
        )

      assert page.can_interact
      assert %Ecto.Changeset{} = page.comment_changeset
      assert %Ecto.Changeset{} = page.tag_changeset
      assert %Ecto.Changeset{} = page.hide_changeset
    end

    test "a banned viewer gets no write controls or mutation changesets" do
      user = confirmed_user_fixture()
      image = image_fixture()

      page = Images.show_image_page(actor(user, ban: @ban), image, page: 1, page_size: 25)

      refute page.can_interact
      assert page.interactions == []
      assert page.comment_changeset == nil
      assert page.description_changeset == nil
      assert page.tag_changeset == nil
      assert page.source_changeset == nil
      assert page.file_changeset == nil
      assert page.hide_changeset == nil
      assert page.feature_changeset == nil
      assert page.repair_changeset == nil
      assert page.hash_changeset == nil
      assert page.uploader_changeset == nil
    end

    test "a forced-filtered image gets no write controls or mutation changesets" do
      image = image_fixture()

      {user, _filter} =
        force_filter(confirmed_user_fixture(), hidden_complex_str: "id:#{image.id}")

      page = Images.show_image_page(actor(user), image, page: 1, page_size: 25)

      refute page.can_interact
      assert page.interactions == []
      assert page.comment_changeset == nil
      assert page.description_changeset == nil
      assert page.tag_changeset == nil
      assert page.source_changeset == nil
      assert page.file_changeset == nil
      assert page.hide_changeset == nil
      assert page.feature_changeset == nil
      assert page.repair_changeset == nil
      assert page.hash_changeset == nil
      assert page.uploader_changeset == nil
    end

    test "a hidden image gets no interaction controls even for a moderator" do
      moderator = moderator_user_fixture()
      image = image_fixture(hidden_from_users: true)

      page = Images.show_image_page(actor(moderator), image, page: 1, page_size: 25)

      refute page.can_interact
      assert page.interactions == []
      assert page.comment_changeset == nil
      assert %Ecto.Changeset{} = page.description_changeset
      assert %Ecto.Changeset{} = page.tag_changeset
      assert %Ecto.Changeset{} = page.source_changeset
      assert %Ecto.Changeset{} = page.file_changeset
      assert %Ecto.Changeset{} = page.hide_changeset
      assert %Ecto.Changeset{} = page.feature_changeset
      assert %Ecto.Changeset{} = page.repair_changeset
      assert %Ecto.Changeset{} = page.hash_changeset
      assert %Ecto.Changeset{} = page.uploader_changeset
    end

    test "an image uploader can edit the description" do
      uploader = confirmed_user_fixture()
      image = image_fixture(user_id: uploader.id)

      page = Images.show_image_page(actor(uploader), image, page: 1, page_size: 25)

      assert %Ecto.Changeset{} = page.description_changeset
      assert %Ecto.Changeset{} = page.tag_changeset
      assert %Ecto.Changeset{} = page.source_changeset
      refute page.hide_changeset
    end

    test "staff gets changesets for image management actions" do
      staff = moderator_user_fixture()
      image = image_fixture()

      page = Images.show_image_page(actor(staff), image, page: 1, page_size: 25)

      assert %Ecto.Changeset{} = page.description_changeset
      assert %Ecto.Changeset{} = page.tag_changeset
      assert %Ecto.Changeset{} = page.source_changeset
      assert %Ecto.Changeset{} = page.file_changeset
      assert %Ecto.Changeset{} = page.hide_changeset
      assert %Ecto.Changeset{} = page.feature_changeset
      assert %Ecto.Changeset{} = page.repair_changeset
      assert %Ecto.Changeset{} = page.hash_changeset
      assert %Ecto.Changeset{} = page.uploader_changeset
    end

    test "watching is true once the viewer is subscribed" do
      user = confirmed_user_fixture()
      image = image_fixture()
      {:ok, _} = Images.create_subscription(image, user)

      page = Images.show_image_page(actor(user), image, page: 1, page_size: 25)

      assert page.watching
    end

    test "user_galleries pairs each of the viewer's galleries with image membership" do
      user = confirmed_user_fixture()
      image = image_fixture()
      containing = gallery_fixture(user)
      empty = gallery_fixture(user)
      gallery_image_fixture(containing, image)

      page = Images.show_image_page(actor(user), image, page: 1, page_size: 25)

      memberships =
        Map.new(page.user_galleries, fn {gallery, member?} -> {gallery.id, member?} end)

      assert memberships[containing.id] == true
      assert memberships[empty.id] == false
    end

    test "loading the page clears the viewer's image notification" do
      user = confirmed_user_fixture()
      image = image_fixture()
      arrange_comment_notification(image, user)
      assert comment_notification?(image, user)

      Images.show_image_page(actor(user), image, page: 1, page_size: 25)

      refute comment_notification?(image, user)
    end

    test "an oldest-first jump-to-last viewer lands on the final comment page" do
      user = confirmed_user_fixture()

      settings =
        user.settings
        |> Ecto.Changeset.change(comments_newest_first: false, comments_always_jump_to_last: true)
        |> Repo.update!()

      user = %{user | settings: settings}
      image = image_fixture()
      for _ <- 1..3, do: comment_fixture(image, confirmed_user_fixture())

      page = Images.show_image_page(actor(user), image, page: 1, page_size: 2)

      # Three comments over a page size of two put the newest on the second page.
      assert page.comments.page_number == 2
    end

    test "a viewer without the jump preference stays on the requested page" do
      user = confirmed_user_fixture()
      image = image_fixture()
      for _ <- 1..3, do: comment_fixture(image, confirmed_user_fixture())

      page = Images.show_image_page(actor(user), image, page: 1, page_size: 2)

      assert page.comments.page_number == 1
    end
  end

  describe "new_image/1" do
    test "a normal actor gets the upload form changeset" do
      assert {:ok, %Ecto.Changeset{}} = Images.new_image(actor(confirmed_user_fixture()))
    end

    test "an anonymous actor gets the upload form changeset" do
      assert {:ok, %Ecto.Changeset{}} = Images.new_image(actor())
    end

    test "a banned actor may not reach the form" do
      assert Images.new_image(actor(confirmed_user_fixture(), ban: @ban)) == {:error, :ban}
    end

    test "a banned actor is rejected even with a fingerprint" do
      actor = actor(confirmed_user_fixture(), ban: @ban, fingerprint: "d015c342859dde3")

      assert Images.new_image(actor) == {:error, :ban}
    end

    test "an actor whose first request has no fingerprint gets the form changeset" do
      assert {:ok, %Ecto.Changeset{}} = Images.new_image(actor(nil, fingerprint: nil))
    end
  end

  describe "create_image/3" do
    setup do
      allow_async_uploads()
    end

    test "a normal actor uploads an image and the row exists" do
      actor = actor(confirmed_user_fixture())
      :ok = Endpoint.subscribe("firehose")

      assert {:ok, %Image{} = image} =
               Images.create_image(
                 actor,
                 %{"tag_input" => "safe, solo, pony"},
                 media_png_upload()
               )

      assert Repo.get(Image, image.id)
      assert source_urls(image) == []

      assert_receive %Broadcast{
        event: "image:create",
        payload: %{image: %{id: image_id}}
      }

      assert image_id == image.id
      await_async_upload()
    end

    test "uploads valid nested source params and persists the source rows" do
      actor = actor(confirmed_user_fixture())
      sources = ["https://example.com/first", "https://example.com/second"]

      assert {:ok, image} =
               Images.create_image(
                 actor,
                 %{
                   "tag_input" => "safe, solo, pony",
                   "sources" =>
                     sources
                     |> Enum.with_index()
                     |> Map.new(fn {source, index} ->
                       {to_string(index), %{"source" => source}}
                     end)
                 },
                 media_png_upload()
               )

      assert source_urls(image) == Enum.sort(sources)
      await_async_upload()
    end

    test "ignores blank source rows during upload" do
      actor = actor(confirmed_user_fixture())

      assert {:ok, image} =
               Images.create_image(
                 actor,
                 %{
                   "tag_input" => "safe, solo, pony",
                   "sources" => %{
                     "0" => %{"source" => ""},
                     "1" => %{"source" => "https://example.com/source"},
                     "2" => %{"source" => ""}
                   }
                 },
                 media_png_upload()
               )

      assert source_urls(image) == ["https://example.com/source"]
      await_async_upload()
    end

    test "invalid upload source URLs return an image-backed changeset" do
      actor = actor(confirmed_user_fixture())

      assert {:error, %Ecto.Changeset{data: %Image{} = image} = changeset} =
               Images.create_image(
                 actor,
                 %{
                   "tag_input" => "safe, solo, pony",
                   "sources" => %{"0" => %{"source" => "not-a-url"}}
                 },
                 media_png_upload()
               )

      assert image.id == nil
      assert [%Ecto.Changeset{} = source_changeset] = get_change(changeset, :sources)
      assert "has invalid format" in errors_on(source_changeset).source
    end

    test "a trusted actor's approved upload increments the count and suggests verification" do
      user = admin_user_fixture()
      rule_fixture(name: "Verification")

      user
      |> Ecto.Changeset.change(images_count: 4)
      |> Repo.update!()

      assert {:ok, image} =
               Images.create_image(
                 actor(user),
                 %{"tag_input" => "safe, solo, pony"},
                 media_png_upload()
               )

      assert image.approved
      assert Repo.reload!(user).images_count == 5

      assert %Report{reported_user_id: user_id, system: true} =
               Repo.one!(from report in Report, where: report.reported_user_id == ^user.id)

      assert user_id == user.id

      await_async_upload()
    end

    test "a banned actor may not upload" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Images.create_image(actor, %{"tag_input" => "safe"}, media_png_upload()) ==
               {:error, :ban}
    end

    test "an actor with no fingerprint may not upload" do
      actor = actor(confirmed_user_fixture(), fingerprint: nil)

      assert Images.create_image(actor, %{"tag_input" => "safe"}, media_png_upload()) ==
               {:error, :unauthorized}
    end

    test "a ban outranks a missing fingerprint" do
      actor = actor(confirmed_user_fixture(), ban: @ban, fingerprint: nil)

      assert Images.create_image(actor, %{"tag_input" => "safe"}, media_png_upload()) ==
               {:error, :ban}
    end

    test "an over-limit actor is rate limited and no image is created" do
      # The :image_create counter is primed past the limit, so the rate check
      # (after write-access, before create_image) refuses the upload, spawning no
      # background process.
      actor = actor(confirmed_user_fixture())
      exceed_rate_limit(actor, :image_create)

      assert Images.create_image(actor, %{"tag_input" => "safe"}, media_png_upload()) ==
               {:error, :rate_limited}

      assert Repo.aggregate(Image, :count) == 0
    end

    test "a successful upload records the counter" do
      actor = actor(confirmed_user_fixture())
      track_rate_limit(actor, :image_create)

      assert {:ok, %Image{}} =
               Images.create_image(
                 actor,
                 %{"tag_input" => "safe, solo, pony"},
                 media_png_upload()
               )

      # Recording happens synchronously once create_image succeeds.
      assert rate_limit_count(actor, :image_create) == "1"

      await_async_upload()
    end

    test "the rate check precedes create_image: over-limit with empty params is still rate limited" do
      # create_image would reject empty params, but the rate check runs first, so
      # an over-limit actor gets :rate_limited rather than a create failure.
      actor = actor(confirmed_user_fixture())
      exceed_rate_limit(actor, :image_create)

      assert Images.create_image(actor, %{}, nil) == {:error, :rate_limited}
    end
  end

  describe "list_approval_queue/2" do
    test "a moderator gets the unapproved images, oldest first, with tags preloaded" do
      approved = image_fixture(approved: true)
      first = image_fixture(approved: false)
      second = image_fixture(approved: false)

      assert {:ok, page} =
               Images.list_approval_queue(actor(moderator_user_fixture()), @approval_pagination)

      assert %Scrivener.Page{} = page

      ids = Enum.map(page.entries, & &1.id)
      assert first.id in ids
      assert second.id in ids
      refute approved.id in ids

      # Oldest first: the ids come back ascending.
      assert ids == Enum.sort(ids)

      entry = Enum.find(page.entries, &(&1.id == first.id))
      assert Ecto.assoc_loaded?(entry.tags)
    end

    test "an admin gets the approval queue" do
      image = image_fixture(approved: false)

      assert {:ok, page} =
               Images.list_approval_queue(actor(admin_user_fixture()), @approval_pagination)

      assert image.id in Enum.map(page.entries, & &1.id)
    end

    test "a regular user is not authorized" do
      assert Images.list_approval_queue(actor(confirmed_user_fixture()), @approval_pagination) ==
               {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      assert Images.list_approval_queue(actor(), @approval_pagination) == {:error, :unauthorized}
    end
  end

  describe "update_batch_tags/2" do
    test "an admin adds a tag to matched images and logs against their own profile" do
      # A letters-only name keeps the profile subject_path identical to
      # "/profiles/<slug>" with no percent-encoding.
      admin = admin_user_fixture(%{name: "batchtagger"})
      actor = actor(admin)
      tag_fixture(%{name: "batchadd"})
      image = image_fixture(tags: "safe")

      assert {:ok, result} =
               Images.update_batch_tags(actor, %{tag_list: "batchadd", image_ids: [image.id]})

      assert result == %{succeeded: 1, failed: 0}
      assert "batchadd" in image_tag_names(image)

      :ok = Endpoint.subscribe("firehose")

      assert {:ok, _result} =
               Images.update_batch_tags(actor, %{tag_list: "-batchadd", image_ids: [image.id]})

      assert_receive %Broadcast{
        event: "image:batch_tag_update",
        payload: %{image_ids: [image_id], added: [], removed: ["batchadd"]}
      }

      assert image_id == image.id

      log = Repo.one!(from log in ModerationLog, order_by: [desc: log.id], limit: 1)
      assert log.user_id == admin.id
      assert log.type == "Admin.Batch.Tag:update"
      assert log.subject_path == "/profiles/#{admin.slug}"
      assert log.body == "Batch tagged '-batchadd' on 1 images"
    end

    test "an admin removes a tag from matched images" do
      actor = actor(admin_user_fixture())
      image = image_fixture(tags: "safe, removeme")

      assert {:ok, result} =
               Images.update_batch_tags(actor, %{tag_list: "-removeme", image_ids: [image.id]})

      assert result == %{succeeded: 1, failed: 0}
      refute "removeme" in image_tag_names(image)
    end

    test "canonicalizes aliases for additions and removals" do
      actor = actor(admin_user_fixture())
      canonical = tag_fixture(name: unique_tag_name())

      alias_tag =
        tag_fixture(name: unique_tag_name())
        |> Ecto.Changeset.change(aliased_tag_id: canonical.id)
        |> Repo.update!()

      image = image_fixture()

      assert {:ok, result} =
               Images.update_batch_tags(actor, %{tag_list: alias_tag.name, image_ids: [image.id]})

      assert result == %{succeeded: 1, failed: 0}
      assert canonical.name in image_tag_names(image)
      refute alias_tag.name in image_tag_names(image)

      assert {:ok, result} =
               Images.update_batch_tags(actor, %{
                 tag_list: "-#{alias_tag.name}",
                 image_ids: [image.id]
               })

      assert result == %{succeeded: 1, failed: 0}
      refute canonical.name in image_tag_names(image)
    end

    test "a moderator with a Tag batch_update grant is authorized" do
      user = %{confirmed_user_fixture() | role_map: %{"Tag" => %{"batch_update" => []}}}
      tag_fixture(%{name: "batchadd"})
      image = image_fixture(tags: "safe")

      assert {:ok, result} =
               Images.update_batch_tags(actor(user), %{
                 tag_list: "batchadd",
                 image_ids: [image.id]
               })

      assert result == %{succeeded: 1, failed: 0}
    end

    test "a batch tag grant does not allow changes to inaccessible hidden images" do
      user = %{confirmed_user_fixture() | role_map: %{"Tag" => %{"batch_update" => []}}}
      visible = image_fixture(tags: "safe, removeme")
      hidden = image_fixture(tags: "safe, removeme", hidden_from_users: true)
      added = tag_fixture(name: "batchadd")
      :ok = Endpoint.subscribe("firehose")

      assert {:ok, %{succeeded: 1, failed: 1}} =
               Images.update_batch_tags(actor(user), %{
                 tag_list: "batchadd, -removeme",
                 image_ids: [hidden.id, visible.id]
               })

      assert "batchadd" in image_tag_names(visible)
      refute "removeme" in image_tag_names(visible)
      refute "batchadd" in image_tag_names(hidden)
      assert "removeme" in image_tag_names(hidden)
      assert Repo.get!(Tag, added.id).images_count == 1
      refute Repo.exists?(from change in TagChange, where: change.image_id == ^hidden.id)
      assert only_moderation_log!().body == "Batch tagged 'batchadd, -removeme' on 1 images"

      assert_receive %Broadcast{
        event: "image:batch_tag_update",
        payload: %{image_ids: [image_id]}
      }

      assert image_id == visible.id
    end

    test "an assistant with image visibility and batch tag grants can update hidden images" do
      user = %{
        confirmed_user_fixture()
        | role: "assistant",
          role_map: %{"Tag" => %{"batch_update" => []}, "Image" => %{"moderator" => []}}
      }

      hidden = image_fixture(hidden_from_users: true)
      added = tag_fixture(name: "batchadd")

      assert {:ok, %{succeeded: 1, failed: 0}} =
               Images.update_batch_tags(actor(user), %{
                 tag_list: added.name,
                 image_ids: [hidden.id]
               })

      assert added.name in image_tag_names(hidden)
      assert Repo.get!(Tag, added.id).images_count == 0
    end

    test "a plain moderator is not authorized" do
      image = image_fixture(tags: "safe")

      assert Images.update_batch_tags(
               actor(moderator_user_fixture()),
               %{tag_list: "batchadd", image_ids: [image.id]}
             ) ==
               {:error, :unauthorized}
    end

    test "a regular user is not authorized" do
      image = image_fixture(tags: "safe")

      assert Images.update_batch_tags(
               actor(confirmed_user_fixture()),
               %{tag_list: "batchadd", image_ids: [image.id]}
             ) ==
               {:error, :unauthorized}
    end

    test "an anonymous actor is not authorized" do
      image = image_fixture(tags: "safe")

      assert Images.update_batch_tags(actor(), %{tag_list: "batchadd", image_ids: [image.id]}) ==
               {:error, :unauthorized}
    end

    test "an unknown-but-castable id lands in failed, not succeeded" do
      actor = actor(admin_user_fixture())
      tag_fixture(%{name: "batchadd"})
      image = image_fixture(tags: "safe")

      assert {:ok, result} =
               Images.update_batch_tags(actor, %{
                 tag_list: "batchadd",
                 image_ids: [image.id, 2_147_483_647]
               })

      assert result == %{succeeded: 1, failed: 1}
    end

    test "processes image IDs in chunks of 1,000" do
      actor = actor(admin_user_fixture())
      tag_fixture(%{name: "batchadd"})
      :ok = Endpoint.subscribe("firehose")

      image_ids = Enum.to_list(2_000_000_000..2_000_001_000)

      assert {:ok, result} =
               Images.update_batch_tags(actor, %{tag_list: "batchadd", image_ids: image_ids})

      assert result == %{succeeded: 0, failed: 1_001}
      assert moderation_log_count() == 2
      assert_receive %Broadcast{event: "image:batch_tag_update", payload: %{image_ids: []}}
      assert_receive %Broadcast{event: "image:batch_tag_update", payload: %{image_ids: []}}
    end

    test "a non-castable id returns the form changeset" do
      actor = actor(admin_user_fixture())
      tag_fixture(%{name: "batchadd"})
      image = image_fixture(tags: "safe")

      assert {:error, %Ecto.Changeset{} = changeset} =
               Images.update_batch_tags(actor, %{
                 tag_list: "batchadd",
                 image_ids: [image.id, "abc"]
               })

      assert changeset.errors[:image_ids]
    end

    test "the log counts only the images the batch matched" do
      actor = actor(admin_user_fixture())
      tag_fixture(%{name: "batchadd"})
      image = image_fixture(tags: "safe")

      assert {:ok, %{succeeded: 1, failed: 1}} =
               Images.update_batch_tags(actor, %{
                 tag_list: "batchadd",
                 image_ids: [image.id, 2_147_483_647]
               })

      log = only_moderation_log!()
      assert log.body == "Batch tagged 'batchadd' on 1 images"
    end

    test "an admin updates hidden images without including them in tag image counts" do
      actor = actor(admin_user_fixture())
      visible = image_fixture()
      hidden = image_fixture(hidden_from_users: true)
      tag_fixture(%{name: "batchhiddentag"})

      assert {:ok, result} =
               Images.update_batch_tags(actor, %{
                 tag_list: "batchhiddentag",
                 image_ids: [hidden.id, visible.id]
               })

      assert result == %{succeeded: 2, failed: 0}
      assert "batchhiddentag" in image_tag_names(hidden)
      assert "batchhiddentag" in image_tag_names(visible)
      assert Repo.get_by!(Tag, name: "batchhiddentag").images_count == 1

      assert {:ok, result} =
               Images.update_batch_tags(actor, %{
                 tag_list: "-batchhiddentag",
                 image_ids: [hidden.id]
               })

      assert result == %{succeeded: 1, failed: 0}
      refute "batchhiddentag" in image_tag_names(hidden)
      assert "batchhiddentag" in image_tag_names(visible)
      assert Repo.get_by!(Tag, name: "batchhiddentag").images_count == 1
    end
  end

  describe "list_images/1" do
    @describetag :search

    setup do
      Search.clear_index!(Image)
      :ok
    end

    test "a visible older image appears for an anonymous scope, with tags preloaded" do
      image = image_fixture(created_at: minutes_ago(4))
      SearchHelpers.reindex_all!(Image)

      page = Images.list_images(actor(), index_scope())

      assert %Scrivener.Page{} = page
      ids = Enum.map(page.entries, & &1.id)
      assert image.id in ids

      entry = Enum.find(page.entries, &(&1.id == image.id))
      assert Ecto.assoc_loaded?(entry.tags)
    end

    test "a recent image is held back by the front-page upload delay" do
      image = image_fixture(created_at: minutes_ago(1))
      SearchHelpers.reindex_all!(Image)

      page = Images.list_images(actor(), index_scope())

      refute image.id in Enum.map(page.entries, & &1.id)
    end
  end

  describe "query_images/1" do
    @describetag :search

    setup do
      Search.clear_index!(Image)
      :ok
    end

    test "a wildcard query returns the record page and an empty sidebar tag list" do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      assert {:ok, %{images: page, tags: []}} =
               Images.query_images(actor(), search_scope(%{"q" => "*"}))

      assert %Scrivener.Page{} = page
      assert image.id in Enum.map(page.entries, & &1.id)
    end

    test "a single-tag query returns the raw Tag record it names in the sidebar list" do
      _image = image_fixture(tags: "safe")
      SearchHelpers.reindex_all!(Image)

      assert {:ok, %{tags: tags}} = Images.query_images(actor(), search_scope(%{"q" => "safe"}))

      assert [%Tag{} = tag] = tags
      assert tag.name == "safe"
      assert is_integer(tag.id)
    end

    test "a malformed query returns the compiler error tuple" do
      assert {:error, msg} =
               Images.query_images(actor(), search_scope(%{"q" => "width.gte:abc"}))

      assert is_binary(msg)
    end

    # A custom sort field (anything under "sf" other than id/first_seen_at)
    # needs its sort cursor, so the page is loaded with hits and each entry is
    # a {record, hit} tuple.
    test "a custom sort field pairs each entry with its raw hit" do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      assert {:ok, %{images: page}} =
               Images.query_images(actor(), search_scope(%{"q" => "*", "sf" => "score"}))

      assert Enum.all?(page.entries, &match?({%Image{}, hit} when is_map(hit), &1))
      assert {%Image{id: id}, _hit} = Enum.find(page.entries, &(elem(&1, 0).id == image.id))
      assert id == image.id
    end

    test "the default sort returns plain records" do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      assert {:ok, %{images: page}} = Images.query_images(actor(), search_scope(%{"q" => "*"}))

      assert Enum.all?(page.entries, &match?(%Image{}, &1))
      assert image.id in Enum.map(page.entries, & &1.id)
    end

    test "sf=id returns plain records" do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      assert {:ok, %{images: page}} =
               Images.query_images(actor(), search_scope(%{"q" => "*", "sf" => "id"}))

      assert Enum.all?(page.entries, &match?(%Image{}, &1))
      assert image.id in Enum.map(page.entries, & &1.id)
    end

    test "sf=first_seen_at returns plain records" do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      assert {:ok, %{images: page}} =
               Images.query_images(actor(), search_scope(%{"q" => "*", "sf" => "first_seen_at"}))

      assert Enum.all?(page.entries, &match?(%Image{}, &1))
      assert image.id in Enum.map(page.entries, & &1.id)
    end
  end
end
