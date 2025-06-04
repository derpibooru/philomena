defmodule Philomena.Images do
  @moduledoc """
  The Images context.
  """

  import Ecto.Query, warn: false
  require Logger

  alias Ecto.Multi
  alias Philomena.Repo

  alias PhilomenaQuery.Search
  alias Philomena.ThumbnailWorker
  alias Philomena.ImagePurgeWorker
  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Images.Image
  alias Philomena.Images.Uploader
  alias Philomena.Images.Tagging
  alias Philomena.Images.Thumbnailer
  alias Philomena.Images.Source
  alias Philomena.Images.SearchIndex, as: ImageIndex
  alias Philomena.IndexWorker
  alias Philomena.ImageFeatures.ImageFeature
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.Notifications.ImageCommentNotification
  alias Philomena.Notifications.ImageMergeNotification
  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChange
  alias Philomena.TagChanges.Limits
  alias Philomena.Tags
  alias Philomena.UserStatistics
  alias Philomena.Tags.Tag
  alias Philomena.Notifications
  alias Philomena.Interactions
  alias Philomena.Reports
  alias Philomena.Comments
  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries.Interaction
  alias Philomena.Users.User
  alias Philomena.Games.{Player, Team}

  use Philomena.Subscriptions,
    on_delete: :clear_image_notification,
    id_name: :image_id

  @doc """
  Gets a single image.

  Raises `Ecto.NoResultsError` if the Image does not exist.

  ## Examples

      iex> get_image!(123)
      %Image{}

      iex> get_image!(456)
      ** (Ecto.NoResultsError)

  """
  def get_image!(id) do
    Repo.one!(Image |> where(id: ^id) |> preload(:tags))
  end

  @doc """
  Gets the tag list for a single image.
  """
  def tag_list(%Image{tags: tags}) do
    tags
    |> Tag.display_order()
    |> Enum.map_join(", ", & &1.name)
  end

  @doc """
  Creates a image.

  ## Examples

      iex> create_image(%{field: value})
      {:ok, %Image{}}

      iex> create_image(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_image(attribution, attrs \\ %{}) do
    tags = Tags.get_or_create_tags(attrs["tag_input"])
    sources = attrs["sources"]

    image =
      %Image{}
      |> Image.creation_changeset(attrs, attribution)
      |> Image.source_changeset(attrs, [], sources)
      |> Image.tag_changeset(attrs, [], tags)
      |> Image.dnp_changeset(attribution[:user])
      |> Uploader.analyze_upload(attrs)

    Multi.new()
    |> Multi.insert(:image, image)
    |> Multi.run(:added_tag_count, fn repo, %{image: image} ->
      tag_ids = image.added_tags |> Enum.map(& &1.id)

      count = Tags.update_image_counts(repo, 1, tag_ids)

      {:ok, count}
    end)
    |> maybe_subscribe_on(:image, attribution[:user], :watch_on_upload)
    |> Repo.transaction()
    |> case do
      {:ok, %{image: image}} ->
        upload_pid = async_upload(image, attrs["image"])
        reindex_image(image)
        Tags.reindex_tags(image.added_tags)
        maybe_approve_image(image, attribution[:user])

        # Return the upload PID along with the created image so that the caller
        # can control the lifecycle of the upload if needed. It's useful, for
        # example for the seeding process to know when to delete the temp file
        # used for uploading.
        {:ok, %{image: image, upload_pid: upload_pid}}

      result ->
        result
    end
  end

  defp async_upload(image, plug_upload) do
    linked_pid =
      spawn(fn ->
        # Make sure task will finish before VM exit
        Process.flag(:trap_exit, true)

        # Wait to be freed up by the caller
        receive do
          :ready -> nil
        end

        # Start trying to upload
        try_upload(image, 0)
      end)

    # Give the upload to the linked process
    Plug.Upload.give_away(plug_upload, linked_pid, self())

    # Free up the linked process
    send(linked_pid, :ready)

    linked_pid
  end

  defp try_upload(image, retry_count) when retry_count < 100 do
    try do
      Uploader.persist_upload(image)
      repair_image(image)
    rescue
      e ->
        Logger.error("Upload failed: #{inspect(e)} [try ##{retry_count}]")
        Process.sleep(5000)
        try_upload(image, retry_count + 1)
    end
  end

  defp try_upload(image, retry_count) do
    Logger.error("Aborting upload of #{image.id} after #{retry_count} retries")
  end

  @doc """
  Approves an image for public viewing.

  This will make the image visible to users and update necessary statistics.

  ## Examples

      iex> approve_image(image)
      {:ok, %Image{}}
  """
  def approve_image(image) do
    image
    |> Repo.preload(:user)
    |> Image.approve_changeset()
    |> Repo.update()
    |> case do
      {:ok, image} ->
        reindex_image(image)
        increment_user_stats(image.user)
        maybe_suggest_user_verification(image.user)

        {:ok, image}

      error ->
        error
    end
  end

  defp maybe_approve_image(_image, nil), do: false

  defp maybe_approve_image(_image, %User{verified: false, role: role}) when role == "user",
    do: false

  defp maybe_approve_image(image, _user), do: approve_image(image)

  defp increment_user_stats(nil), do: false

  defp increment_user_stats(%User{} = user) do
    UserStatistics.inc_stat(user, :uploads)
  end

  defp maybe_suggest_user_verification(%User{id: id, uploads_count: 5, verified: false}) do
    Reports.create_system_report(
      {"User", id},
      "Verification",
      "User has uploaded enough approved images to be considered for verification."
    )
  end

  defp maybe_suggest_user_verification(_user), do: false

  @doc """
  Counts the number of images pending approval that a user can moderate.

  ## Examples

      iex> count_pending_approvals(admin)
      42

      iex> count_pending_approvals(user)
      nil

  """
  def count_pending_approvals(user) do
    if Canada.Can.can?(user, :approve, %Image{}) do
      Image
      |> where(approved: false)
      |> Repo.aggregate(:count)
    else
      nil
    end
  end

  @doc """
  Marks the given image as the current featured image.

  ## Examples

      iex> feature_image(user, image)
      {:ok, %ImageFeature{}}

  """
  def feature_image(featurer, %Image{} = image) do
    %ImageFeature{user_id: featurer.id, image_id: image.id}
    |> ImageFeature.changeset(%{})
    |> Repo.insert()
  end

  @doc """
  Destroys the contents of an image (hard deletion) by marking it as hidden
  and deleting up associated files.

  This will:
  1. Mark the image as removed in the database
  2. Purge associated files
  3. Remove thumbnails

  ## Examples

      iex> destroy_image(image)
      {:ok, %Image{}}

  """
  def destroy_image(%Image{} = image) do
    image
    |> Image.remove_image_changeset()
    |> Repo.update()
    |> case do
      {:ok, image} ->
        purge_files(image, image.hidden_image_key)
        Thumbnailer.destroy_thumbnails(image)

        {:ok, image}

      error ->
        error
    end
  end

  @doc """
  Locks or unlocks comments on an image.

  ## Examples

      iex> lock_comments(image, true)
      {:ok, %Image{}}

  """
  def lock_comments(%Image{} = image, locked) do
    image
    |> Image.lock_comments_changeset(locked)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Locks or unlocks the description of an image.

  ## Examples

      iex> lock_description(image, true)
      {:ok, %Image{}}

  """
  def lock_description(%Image{} = image, locked) do
    image
    |> Image.lock_description_changeset(locked)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Locks or unlocks the tags on an image.

  ## Examples

      iex> lock_tags(image, true)
      {:ok, %Image{}}

  """
  def lock_tags(%Image{} = image, locked) do
    image
    |> Image.lock_tags_changeset(locked)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Removes the original SHA-512 hash from an image, allowing users to upload
  the same file again.

  ## Examples

      iex> remove_hash(image)
      {:ok, %Image{}}

  """
  def remove_hash(%Image{} = image) do
    image
    |> Image.remove_hash_changeset()
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Updates the scratchpad notes on an image.

  ## Examples

      iex> update_scratchpad(image, %{"scratchpad" => "New notes"})
      {:ok, %Image{}}

  """
  def update_scratchpad(%Image{} = image, attrs) do
    image
    |> Image.scratchpad_changeset(attrs)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Removes all source change history for an image.

  ## Examples

      iex> remove_source_history(image)
      {:ok, %Image{}}

  """
  def remove_source_history(%Image{} = image) do
    image
    |> Repo.preload(:source_changes)
    |> Image.remove_source_history_changeset()
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Repairs an image by regenerating its thumbnails.
  Returns the image struct unchanged, for use in a pipeline.

  This will:
  1. Mark the image as needing thumbnail regeneration
  2. Queue the thumbnail generation job

  ## Examples

      iex> repair_image(image)
      %Image{}

  """
  def repair_image(%Image{} = image) do
    Image
    |> where(id: ^image.id)
    |> Repo.update_all(set: [thumbnails_generated: false, processed: false])

    Exq.enqueue(Exq, queue(image.image_mime_type), ThumbnailWorker, [image.id])

    image
  end

  defp queue("video/webm"), do: "videos"
  defp queue(_mime_type), do: "images"

  @doc """
  Updates the file content of an image.

  This will:
  1. Update the image metadata
  2. Save the new file
  3. Generate new thumbnails
  4. Purge old files
  5. Reindex the image

  ## Examples

      iex> update_file(image, %{"image" => upload})
      {:ok, %Image{}}

  """
  def update_file(%Image{} = image, attrs) do
    image
    |> Image.changeset(attrs)
    |> Uploader.analyze_upload(attrs)
    |> Repo.update()
    |> case do
      {:ok, image} ->
        Uploader.persist_upload(image)

        repair_image(image)
        purge_files(image, image.hidden_image_key)
        reindex_image(image)

        {:ok, image}

      error ->
        error
    end
  end

  @doc """
  Updates a image.

  ## Examples

      iex> update_image(image, %{field: new_value})
      {:ok, %Image{}}

      iex> update_image(image, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_image(%Image{} = image, attrs) do
    image
    |> Image.changeset(attrs)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Updates an image's description.

  ## Examples

      iex> update_description(image, %{"description" => "New description"})
      {:ok, %Image{}}

  """
  def update_description(%Image{} = image, attrs) do
    image
    |> Image.description_changeset(attrs)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Updates an image's sources with attribution tracking.

  Handles both added and removed sources. Automatically determines the user's
  intended source changes based on the provided previous image state.

  This will update the image's sources, create source change records
  for tracking, and reindex the image.

  ## Examples

      iex> update_sources(
      ...>   image,
      ...>   %{attribution: attrs},
      ...>   %{
      ...>     "old_sources" => %{},
      ...>     "sources" => %{"0" => "http://example.com"}
      ...>    }
      ...> )
      {:ok,
       %{
         image: image,
         added_source_changes: 1,
         removed_source_changes: 0
       }}

  """
  def update_sources(%Image{} = image, attribution, attrs) do
    old_sources = attrs["old_sources"]
    new_sources = attrs["sources"]

    Multi.new()
    |> Multi.run(:image, fn repo, _chg ->
      image = repo.preload(image, [:sources])

      image
      |> Image.source_changeset(%{}, old_sources, new_sources)
      |> repo.update()
      |> case do
        {:ok, image} ->
          {:ok, {image, image.added_sources, image.removed_sources}}

        error ->
          error
      end
    end)
    |> Multi.run(:added_source_changes, fn repo, %{image: {image, added_sources, _removed}} ->
      source_changes =
        added_sources
        |> Enum.map(&source_change_attributes(attribution, image, &1, true, attribution[:user]))

      {count, nil} = repo.insert_all(SourceChange, source_changes)

      {:ok, count}
    end)
    |> Multi.run(:removed_source_changes, fn repo, %{image: {image, _added, removed_sources}} ->
      source_changes =
        removed_sources
        |> Enum.map(&source_change_attributes(attribution, image, &1, false, attribution[:user]))

      {count, nil} = repo.insert_all(SourceChange, source_changes)

      {:ok, count}
    end)
    |> Repo.transaction()
  end

  defp source_change_attributes(attribution, image, source, added, user) do
    now = DateTime.utc_now(:second)

    user_id =
      case user do
        nil -> nil
        user -> user.id
      end

    %{
      image_id: image.id,
      source_url: source,
      user_id: user_id,
      created_at: now,
      updated_at: now,
      ip: attribution[:ip],
      fingerprint: attribution[:fingerprint],
      added: added
    }
  end

  @doc """
  Updates the locked tags on an image.

  Locked tags can only be added or removed by privileged users.

  ## Examples

      iex> update_locked_tags(image, %{tag_input: "safe, validated"})
      {:ok, %Image{}}

  """
  def update_locked_tags(%Image{} = image, attrs) do
    new_tags = Tags.get_or_create_tags(attrs["tag_input"])

    image
    |> Repo.preload(:locked_tags)
    |> Image.locked_tags_changeset(attrs, new_tags)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Updates an image's tags with attribution tracking.

  Handles both added and removed tags. Automatically determines the user's
  intended tag changes based on the provided previous image state.

  This will update the image's tags, create tag change records
  for tracking, and reindex the image.

  ## Examples

      iex> update_tags(
      ...>   image,
      ...>   %{attribution: attrs},
      ...>   %{
      ...>     old_tag_input: "safe",
      ...>     tag_input: "safe, cute"
      ...>   }
      ...> )
      {:ok,
       %{
         image: image,
         tag_changes: {1, 0}
       }}

  """
  def update_tags(%Image{} = image, attribution, attrs) do
    old_tags = Tags.get_or_create_tags(attrs["old_tag_input"])
    new_tags = Tags.get_or_create_tags(attrs["tag_input"])

    Multi.new()
    |> Multi.run(:image, fn repo, _chg ->
      image = repo.preload(image, [:tags, :locked_tags])

      image
      |> Image.tag_changeset(%{}, old_tags, new_tags, image.locked_tags)
      |> repo.update()
      |> case do
        {:ok, image} ->
          {:ok, {image, image.added_tags, image.removed_tags}}

        error ->
          error
      end
    end)
    |> Multi.run(:check_limits, fn _repo, %{image: {image, _added, _removed}} ->
      check_tag_change_limits_before_commit(image, attribution)
    end)
    |> Multi.run(:tag_changes, fn
      _repo, %{image: {_image, [], []}} ->
        {:ok, {0, 0}}

      _repo, %{image: {image, added_tags, removed_tags}} ->
        TagChanges.create_tag_change(
          image,
          attribution,
          added_tags,
          removed_tags
        )
    end)
    |> Multi.run(:added_tag_count, fn
      _repo, %{image: {%{hidden_from_users: true}, _added, _removed}} ->
        {:ok, 0}

      repo, %{image: {_image, added_tags, _removed}} ->
        tag_ids = added_tags |> Enum.map(& &1.id)

        count = Tags.update_image_counts(repo, 1, tag_ids)

        {:ok, count}
    end)
    |> Multi.run(:removed_tag_count, fn
      _repo, %{image: {%{hidden_from_users: true}, _added, _removed}} ->
        {:ok, 0}

      repo, %{image: {_image, _added, removed_tags}} ->
        tag_ids = removed_tags |> Enum.map(& &1.id)

        count = Tags.update_image_counts(repo, -1, tag_ids)

        {:ok, count}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{image: {image, _added, _removed}}} = res ->
        update_tag_change_limits_after_commit(image, attribution)

        res

      err ->
        err
    end
  end

  defp check_tag_change_limits_before_commit(image, attribution) do
    tag_changed_count = length(image.added_tags) + length(image.removed_tags)
    rating_changed = image.ratings_changed
    user = attribution[:user]
    ip = attribution[:ip]

    cond do
      Limits.limited_for_tag_count?(user, ip, tag_changed_count) ->
        {:error, :limit_exceeded}

      rating_changed and Limits.limited_for_rating_count?(user, ip) ->
        {:error, :limit_exceeded}

      true ->
        {:ok, 0}
    end
  end

  @doc """
  Updates the tag change tracking after committing updates to an image.

  This updates the rate limit counters for total tag change count and rating change count
  based on the changes made to the image.

  ## Examples

      iex> update_tag_change_limits_after_commit(image, %{user: user, ip: "127.0.0.1"})
      :ok

  """
  def update_tag_change_limits_after_commit(image, attribution) do
    rating_changed_count = if(image.ratings_changed, do: 1, else: 0)
    tag_changed_count = length(image.added_tags) + length(image.removed_tags)
    user = attribution[:user]
    ip = attribution[:ip]

    :ok = Limits.update_tag_count_after_update(user, ip, tag_changed_count)
    :ok = Limits.update_rating_count_after_update(user, ip, rating_changed_count)
    :ok
  end

  @doc """
  Changes the uploader of an image.

  ## Examples

      iex> update_uploader(image, %{"username" => "Admin"})
      {:ok, %Image{}}

  """
  def update_uploader(%Image{} = image, attrs) do
    image
    |> Image.uploader_changeset(attrs)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Updates the anonymous status of an image.

  ## Examples

      iex> update_anonymous(image, %{"anonymous" => "true"})
      {:ok, %Image{}}

  """
  def update_anonymous(%Image{} = image, attrs) do
    image
    |> Image.anonymous_changeset(attrs)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Updates the hide reason for an image.

  ## Examples

      iex> update_hide_reason(image, %{hide_reason: "Duplicate of #1234"})
      {:ok, %Image{}}

      iex> update_hide_reason(image, %{hide_reason: ""})
      {:ok, %Image{}}

  """
  def update_hide_reason(%Image{} = image, attrs) do
    image
    |> Image.hide_reason_changeset(attrs)
    |> Repo.update()
    |> reindex_after_update()
  end

  defp reindex_after_update(result) do
    case result do
      {:ok, image} ->
        reindex_image(image)

        {:ok, image}

      error ->
        error
    end
  end

  @doc """
  Hides an image from public view.

  This will:
  1. Mark the image as hidden
  2. Close all reports and duplicate reports
  3. Delete all gallery interactions containing the image
  4. Decrement all tag counts with the image
  5. Hide the image's thumbnails and purge them from the CDN
  6. Reindex the image and all of its comments

  ## Examples

      iex> hide_image(image, moderator, %{reason: "Rule violation"})
      {:ok,
       %{
         image: image,
         tags: tags,
         reports: {count, reports}
       }}

  """
  def hide_image(%Image{} = image, user, attrs) do
    duplicate_reports =
      DuplicateReport
      |> where(state: "open")
      |> where([d], d.image_id == ^image.id or d.duplicate_of_image_id == ^image.id)
      |> update(set: [state: "rejected"])

    image
    |> Image.hide_changeset(attrs, user)
    |> hide_image_multi(image, user, Multi.new())
    |> maybe_remove_points_for_image(Repo.preload(image, :user).user)
    |> Multi.update_all(:duplicate_reports, duplicate_reports, [])
    |> Repo.transaction()
    |> process_after_hide()
  end

  defp maybe_remove_points_for_image(multi, nil), do: multi

  defp maybe_remove_points_for_image(multi, user) do
    user = Repo.preload(user, :game_profiles)

    case user do
      %User{game_profiles: [profile | _]} ->
        profile_query =
          Player
          |> where(user_id: ^user.id)

        team_query =
          Team
          |> where(id: ^profile.team_id)

        multi
        |> Multi.run(:increment_points, fn repo, _changes ->
          repo.update_all(profile_query, inc: [points: -min(profile.points, 15)])
          repo.update_all(team_query, inc: [points: -min(profile.points, 15)])
          {:ok, 0}
        end)

      _ ->
        multi
    end
  end

  @doc """
  Merges one image into another, combining their metadata and content.

  This will:
  1. Hide the source image
  2. Update first_seen_at timestamp
  3. Copy tags to the target image
  4. Migrate sources, comments, subscriptions and interactions
  5. Send merge notifications
  6. Reindex both images and all of the comments

  ## Parameters
  - multi: Optional `m:Ecto.Multi` for transaction handling
  - image: The source image to merge from
  - duplicate_of_image: The target image to merge into
  - user: The user performing the merge

  ## Examples

      iex> merge_image(nil, source_image, target_image, moderator)
      {:ok,
       %{
         image: image,
         tags: tags
       }}

  """
  def merge_image(multi \\ nil, %Image{} = image, duplicate_of_image, user) do
    multi = multi || Multi.new()

    image =
      Repo.preload(image, [:user, :intensity, :sources, tags: :aliases])

    duplicate_of_image =
      Repo.preload(duplicate_of_image, [:user, :intensity, :sources, tags: :aliases])

    image
    |> Image.merge_changeset(duplicate_of_image)
    |> hide_image_multi(image, user, multi)
    |> Multi.run(:first_seen_at, fn _, %{} ->
      update_first_seen_at(
        duplicate_of_image,
        image.first_seen_at,
        duplicate_of_image.first_seen_at
      )
    end)
    |> Multi.run(:copy_tags, fn _, %{} ->
      {:ok, Tags.copy_tags(image, duplicate_of_image)}
    end)
    |> Multi.run(:migrate_sources, fn _, %{} ->
      {:ok, migrate_sources(image, duplicate_of_image)}
    end)
    |> Multi.run(:migrate_comments, fn _, %{} ->
      {:ok, Comments.migrate_comments(image, duplicate_of_image)}
    end)
    |> Multi.run(:migrate_subscriptions, fn _, %{} ->
      {:ok, migrate_subscriptions(image, duplicate_of_image)}
    end)
    |> Multi.run(:migrate_interactions, fn _, %{} ->
      {:ok, Interactions.migrate_interactions(image, duplicate_of_image)}
    end)
    |> Multi.run(:notification, &notify_merge(&1, &2, image, duplicate_of_image))
    |> Repo.transaction()
    |> process_after_hide()
    |> case do
      {:ok, result} ->
        reindex_image(duplicate_of_image)
        Comments.reindex_comments_on_image(duplicate_of_image)

        PhilomenaWeb.Endpoint.broadcast!(
          "firehose",
          "image:merge",
          %{
            image: PhilomenaWeb.Api.Json.ImageView.render("image.json", %{image: image}),
            duplicate_of_image:
              PhilomenaWeb.Api.Json.ImageView.render("image.json", %{image: duplicate_of_image})
          }
        )

        {:ok, result}

      error ->
        error
    end
  end

  defp hide_image_multi(changeset, image, user, multi) do
    report_query = Reports.close_report_query({"Image", image.id}, user)

    galleries =
      Gallery
      |> join(:inner, [g], gi in assoc(g, :interactions), on: gi.image_id == ^image.id)
      |> update(inc: [image_count: -1])

    gallery_interactions = where(Interaction, image_id: ^image.id)

    multi
    |> Multi.update(:image, changeset)
    |> Multi.update_all(:reports, report_query, [])
    |> Multi.update_all(:galleries, galleries, [])
    |> Multi.delete_all(:gallery_interactions, gallery_interactions, [])
    |> Multi.run(:tags, fn repo, %{image: image} ->
      image = Repo.preload(image, :tags, force: true)

      # I'm not convinced this is a good idea. It leads
      # to way too much drift, and the index has to be
      # maintained.
      tag_ids = Enum.map(image.tags, & &1.id)

      Tags.update_image_counts(repo, -1, tag_ids)

      {:ok, image.tags}
    end)
  end

  defp process_after_hide(result) do
    case result do
      {:ok, %{image: image, tags: tags, reports: {_count, reports}} = result} ->
        spawn(fn ->
          Thumbnailer.hide_thumbnails(image, image.hidden_image_key)
          purge_files(image, image.hidden_image_key)
        end)

        Comments.reindex_comments_on_image(image)
        Reports.reindex_reports(reports)
        Tags.reindex_tags(tags)
        reindex_image(image)
        reindex_copied_tags(result)

        {:ok, result}

      error ->
        error
    end
  end

  defp reindex_copied_tags(%{copy_tags: tags}), do: Tags.reindex_tags(tags)
  defp reindex_copied_tags(_result), do: nil

  defp update_first_seen_at(image, time_1, time_2) do
    min_time =
      case DateTime.compare(time_1, time_2) do
        :gt -> time_2
        _ -> time_1
      end

    Image
    |> where(id: ^image.id)
    |> Repo.update_all(set: [first_seen_at: min_time])

    {:ok, image}
  end

  @doc """
  Unhides an image, making it visible to users again.

  This will:
  1. Remove the hidden status from the image
  2. Increment tag counts
  3. Unhide thumbnails
  4. Reindex the image and related content

  Returns {:ok, image} if successful, or returns the image unchanged if it's not hidden.

  ## Examples

      iex> unhide_image(hidden_image)
      {:ok, %Image{hidden_from_users: false}}

      iex> unhide_image(visible_image)
      {:ok, %Image{}}

  """
  def unhide_image(%Image{hidden_from_users: true} = image) do
    key = image.hidden_image_key

    Multi.new()
    |> Multi.update(:image, Image.unhide_changeset(image))
    |> Multi.run(:tags, fn repo, %{image: image} ->
      image = Repo.preload(image, :tags, force: true)

      tag_ids = Enum.map(image.tags, & &1.id)
      query = where(Tag, [t], t.id in ^tag_ids)

      repo.update_all(query, inc: [images_count: 1])

      {:ok, image.tags}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{image: image, tags: tags}} ->
        spawn(fn ->
          Thumbnailer.unhide_thumbnails(image, key)
        end)

        reindex_image(image)
        purge_files(image, image.hidden_image_key)
        Comments.reindex_comments_on_image(image)
        Tags.reindex_tags(tags)

        {:ok, image}

      error ->
        error
    end
  end

  def unhide_image(image), do: {:ok, image}

  @doc """
  Performs a batch update on multiple images, adding and removing tags.

  This function efficiently updates tags for multiple images at once,
  handling tag changes, tag counts, and reindexing in a single transaction.

  ## Parameters
  - image_ids: List of image IDs to update
  - added_tags: List of tags to add to all images
  - removed_tags: List of tags to remove from all images
  - attributes: Attributes tag changes are created with

  ## Note

  All the tags provided to this function must exist in the database.
  If you're not sure if the tags exist or not, use Tags.get_or_create_tags first.

  ## Examples

      iex> batch_update([1, 2], [tag1], [tag2], %{user_id: user.id, ip: ip, fingerprint: "ffff"})
      {:ok, ...}

  """
  def batch_update(image_ids, added_tags, removed_tags, attributes) do
    batch_update(
      Enum.map(image_ids, fn id ->
        %{
          image_id: id,
          added_tags: added_tags,
          removed_tags: removed_tags
        }
      end),
      attributes
    )
  end

  def batch_update(changes, attributes) do
    changes = merge_change_batches(changes)

    image_ids =
      Image
      |> where([i], i.id in ^Enum.map(changes, & &1.image_id) and i.hidden_from_users == false)
      |> select([i], i.id)
      |> Repo.all()

    to_insert =
      Enum.flat_map(changes, fn change ->
        Enum.map(change.added_tags, &%{tag_id: &1.id, image_id: change.image_id})
      end)

    to_delete_ids =
      Enum.flat_map(changes, fn change ->
        Enum.map(change.removed_tags, & &1.id)
      end)

    to_delete =
      Tagging
      |> where([t], t.image_id in ^image_ids and t.tag_id in ^to_delete_ids)
      |> select([t], [t.image_id, t.tag_id])

    now = DateTime.utc_now(:second)
    tag_attributes = %{name: "", slug: "", created_at: now, updated_at: now}

    Repo.transaction(fn ->
      {_count, inserted} =
        Repo.insert_all(Tagging, to_insert,
          on_conflict: :nothing,
          returning: [:image_id, :tag_id]
        )

      {_count, deleted} = Repo.delete_all(to_delete)

      inserted = Enum.map(inserted, &[&1.image_id, &1.tag_id])

      # Create tag change batches for every image ID.
      new_tag_changes =
        (inserted ++ deleted)
        |> Enum.uniq_by(fn [image_id, _] -> image_id end)
        |> Enum.map(fn [image_id, _] ->
          {:ok, tc} =
            %TagChange{
              image_id: image_id,
              user_id: attributes[:user_id],
              ip: attributes[:ip],
              fingerprint: attributes[:fingerprint],
              created_at: now
            }
            |> Repo.insert()

          {image_id, tc}
        end)
        |> Map.new()

      # Create tags belonging to tag changes.
      added_changes = tag_change_data(inserted, new_tag_changes, true)
      removed_changes = tag_change_data(deleted, new_tag_changes, false)

      Repo.insert_all(TagChanges.Tag, added_changes ++ removed_changes)

      # In order to merge into the existing tables here in one go, insert_all
      # is used with a query that is guaranteed to conflict on every row by
      # using the primary key. This will update the image counts via the
      # ON CONFLICT DO UPDATE clause.

      added_upserts = tag_upsert_data(inserted, tag_attributes, true)
      removed_upserts = tag_upsert_data(deleted, tag_attributes, false)

      Repo.insert_all(Tag, added_upserts ++ removed_upserts,
        on_conflict: update(Tag, inc: [images_count: fragment("EXCLUDED.images_count")]),
        conflict_target: [:id]
      )
    end)
    |> case do
      {:ok, _} = result ->
        reindex_images(image_ids)
        Comments.reindex_comments_on_images(image_ids)
        Tags.reindex_tags(Enum.flat_map(changes, &(&1.added_tags ++ &1.removed_tags)))

        result

      result ->
        result
    end
  end

  # Merge any change batches belonging to the same image ID into
  # one single batch, then deduplicate added_tags by removing any
  # which are slated for removal, which is the behavior of the
  # mass tagger anyway (it inserts anything that needs to be inserted
  # into image_taggings, and then deletes anything that needs to be deleted,
  # so by not inserting what would be deleted anyway, we're just mimicking
  # this behavior here, and ensuring that there are no duplicate tag changes
  # per batch)
  defp merge_change_batches(changes) do
    changes
    |> Enum.group_by(& &1.image_id)
    |> Enum.map(fn {image_id, instances} ->
      added =
        instances
        |> Enum.flat_map(& &1.added_tags)
        |> Enum.uniq_by(& &1.id)

      removed =
        instances
        |> Enum.flat_map(& &1.removed_tags)
        |> Enum.uniq_by(& &1.id)

      %{
        image_id: image_id,
        added_tags: Enum.reject(added, fn a -> Enum.any?(removed, &(&1.id == a.id)) end),
        removed_tags: removed
      }
    end)
    |> Enum.reject(&(Enum.empty?(&1.added_tags) && Enum.empty?(&1.removed_tags)))
  end

  # Generate data for TagChanges.Tag struct.
  defp tag_change_data(changes, tag_changes, added) do
    Enum.map(changes, fn [image_id, tag_id] ->
      %{id: id} = Map.get(tag_changes, image_id)

      %{
        tag_change_id: id,
        tag_id: tag_id,
        added: added
      }
    end)
  end

  # Generate data for inserts/updates (hence, upserts) of the Tags.Tag struct.
  defp tag_upsert_data(changes, tag_attributes, added) do
    changes
    |> Enum.group_by(fn [_image_id, tag_id] -> tag_id end)
    |> Enum.map(fn {tag_id, instances} ->
      Map.merge(tag_attributes, %{
        id: tag_id,
        images_count: if(added, do: length(instances), else: -length(instances))
      })
    end)
  end

  @doc """
  Deletes a Image.

  ## Examples

      iex> delete_image(image)
      {:ok, %Image{}}

      iex> delete_image(image)
      {:error, %Ecto.Changeset{}}

  """
  def delete_image(%Image{} = image) do
    Repo.delete(image)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking image changes.

  ## Examples

      iex> change_image(image)
      %Ecto.Changeset{source: %Image{}}

  """
  def change_image(%Image{} = image) do
    Image.changeset(image, %{})
  end

  @doc """
  Updates image search indices when a user's name changes.

  ## Examples

      iex> user_name_reindex("old_username", "new_username")
      :ok

  """
  def user_name_reindex(old_name, new_name) do
    data = ImageIndex.user_name_update_by_query(old_name, new_name)

    Search.update_by_query(Image, data.query, data.set_replacements, data.replacements)
  end

  @doc """
  Queues a single image for search index updates.
  Returns the image struct unchanged, for use in a pipeline.

  ## Examples

      iex> reindex_image(image)
      %Image{}

  """
  def reindex_image(%Image{} = image) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Images", "id", [image.id]])

    image
  end

  @doc """
  Queues all listed image IDs for search index updates.
  Returns the list unchanged, for use in a pipeline.

  ## Examples

      iex> reindex_images([1, 2, 3])
      [1, 2, 3]

  """
  def reindex_images(image_ids) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Images", "id", image_ids])

    image_ids
  end

  @doc """
  Returns the preload configuration for image indexing.

  Specifies which associations should be preloaded when indexing images,
  optimizing the queries for better performance.

  ## Examples

      iex> indexing_preloads()
      [sources: query, user: query, ...]

  """
  def indexing_preloads do
    user_query = select(User, [u], map(u, [:id, :name]))
    sources_query = select(Source, [s], map(s, [:image_id, :source]))
    alias_tags_query = select(Tag, [t], map(t, [:aliased_tag_id, :name]))

    base_tags_query =
      Tag
      |> select([t], [:category, :id, :name])
      |> preload(aliases: ^alias_tags_query)

    [
      :gallery_interactions,
      sources: sources_query,
      user: user_query,
      favers: user_query,
      downvoters: user_query,
      upvoters: user_query,
      hiders: user_query,
      deleter: user_query,
      tags: base_tags_query
    ]
  end

  @doc """
  Performs a search reindex operation on images matching the given criteria.

  ## Parameters
  - column: The database column to filter on (e.g., :id)
  - condition: A list of values to match against the column

  ## Examples

      iex> perform_reindex(:id, [1, 2, 3])
      :ok

  """
  def perform_reindex(column, condition) do
    Image
    |> preload(^indexing_preloads())
    |> where([i], field(i, ^column) in ^condition)
    |> Search.reindex(Image)
  end

  @doc """
  Purges image files from the CDN.

  Enqueues a job to purge both visible and hidden thumbnail paths for the given image.

  ## Examples

      iex> purge_files(image, "hidden_key")
      :ok

  """
  def purge_files(image, hidden_key) do
    files =
      if is_nil(hidden_key) do
        Thumbnailer.thumbnail_urls(image, nil)
      else
        Thumbnailer.thumbnail_urls(image, hidden_key) ++
          Thumbnailer.thumbnail_urls(image, nil)
      end

    Exq.enqueue(Exq, "indexing", ImagePurgeWorker, [files])
  end

  @doc """
  Executes the actual purge operation for image files.

  Calls the system purge-cache command to remove the specified files from the CDN cache.

  ## Examples

      iex> perform_purge(["file1.jpg", "file2.jpg"])
      :ok

  """
  def perform_purge(files) do
    {_out, 0} = System.cmd("purge-cache", [Jason.encode!(%{files: files})])

    :ok
  end

  alias Philomena.Images.Subscription

  @doc """
  Migrates subscriptions and notifications from one image to another.

  This function is used during image merging to transfer all subscriptions
  and notifications from the source image to the target image. It handles:

  1. User subscriptions
  2. Comment notifications
  3. Merge notifications

  Returns `{:ok, {comment_notification_count, merge_notification_count}}`.

  ## Parameters

    - source: The source image to migrate from
    - target: The target image to migrate to

  ## Examples

      iex> migrate_subscriptions(source_image, target_image)
      {:ok, {5, 2}}

  """
  def migrate_subscriptions(source, target) do
    subscriptions =
      Subscription
      |> where(image_id: ^source.id)
      |> select([s], %{image_id: type(^target.id, :integer), user_id: s.user_id})
      |> Repo.all()

    Repo.insert_all(Subscription, subscriptions, on_conflict: :nothing)

    comment_notifications =
      from cn in ImageCommentNotification,
        where: cn.image_id == ^source.id,
        select: %{
          user_id: cn.user_id,
          image_id: ^target.id,
          comment_id: cn.comment_id,
          read: cn.read,
          created_at: cn.created_at,
          updated_at: cn.updated_at
        }

    merge_notifications =
      from mn in ImageMergeNotification,
        where: mn.target_id == ^source.id,
        select: %{
          user_id: mn.user_id,
          target_id: ^target.id,
          source_id: mn.source_id,
          read: mn.read,
          created_at: mn.created_at,
          updated_at: mn.updated_at
        }

    {comment_notification_count, nil} =
      Repo.insert_all(ImageCommentNotification, comment_notifications, on_conflict: :nothing)

    {merge_notification_count, nil} =
      Repo.insert_all(ImageMergeNotification, merge_notifications, on_conflict: :nothing)

    Repo.delete_all(exclude(comment_notifications, :select))
    Repo.delete_all(exclude(merge_notifications, :select))

    {:ok, {comment_notification_count, merge_notification_count}}
  end

  @doc """
  Migrates source URLs from one image to another.

  This function is used during image merging to combine source URLs from both images.
  It will:

  1. Combine sources from both images
  2. Remove duplicates
  3. Take up to 15 sources (the system limit)
  4. Update the target image with the combined sources

  Returns the result of updating the target image with the combined sources.

  ## Parameters
  - source: The source image containing sources to migrate
  - target: The target image to receive the combined sources

  ## Examples

      iex> migrate_sources(source_image, target_image)
      {:ok, %Image{}}

  """
  def migrate_sources(source, target) do
    sources =
      (source.sources ++ target.sources)
      |> Enum.map(fn s -> %Source{image_id: target.id, source: s.source} end)
      |> Enum.uniq()
      |> Enum.take(15)

    target
    |> Image.sources_changeset(sources)
    |> Repo.update()
  end

  defp notify_merge(_repo, _changes, source, target) do
    Notifications.create_image_merge_notification(target, source)
  end

  @doc """
  Removes all image notifications for a given image and user.

  ## Examples

      iex> clear_image_notification(image, user)
      :ok

  """
  def clear_image_notification(%Image{} = image, user) do
    Notifications.clear_image_comment_notification(image, user)
    Notifications.clear_image_merge_notification(image, user)
    :ok
  end
end
