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
  alias Philomena.NotificationWorker
  alias Philomena.TagChanges.Limits
  alias Philomena.TagChanges.TagChange
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
    |> Multi.run(:name_caches, fn repo, %{image: image} ->
      image
      |> Image.cache_changeset()
      |> repo.update()
    end)
    |> Multi.run(:added_tag_count, fn repo, %{image: image} ->
      tag_ids = image.added_tags |> Enum.map(& &1.id)
      tags = Tag |> where([t], t.id in ^tag_ids)

      {count, nil} = repo.update_all(tags, inc: [images_count: 1])

      {:ok, count}
    end)
    |> maybe_subscribe_on(:image, attribution[:user], :watch_on_upload)
    |> Repo.transaction()
    |> case do
      {:ok, %{image: image}} = result ->
        async_upload(image, attrs["image"])
        reindex_image(image)
        Tags.reindex_tags(image.added_tags)
        maybe_approve_image(image, attribution[:user])

        result

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

  def count_pending_approvals(user) do
    if Canada.Can.can?(user, :approve, %Image{}) do
      Image
      |> where(hidden_from_users: false)
      |> where(approved: false)
      |> Repo.aggregate(:count)
    else
      nil
    end
  end

  def feature_image(featurer, %Image{} = image) do
    %ImageFeature{user_id: featurer.id, image_id: image.id}
    |> ImageFeature.changeset(%{})
    |> Repo.insert()
  end

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

  def lock_comments(%Image{} = image, locked) do
    image
    |> Image.lock_comments_changeset(locked)
    |> Repo.update()
  end

  def lock_description(%Image{} = image, locked) do
    image
    |> Image.lock_description_changeset(locked)
    |> Repo.update()
  end

  def lock_tags(%Image{} = image, locked) do
    image
    |> Image.lock_tags_changeset(locked)
    |> Repo.update()
  end

  def remove_hash(%Image{} = image) do
    image
    |> Image.remove_hash_changeset()
    |> Repo.update()
  end

  def update_scratchpad(%Image{} = image, attrs) do
    image
    |> Image.scratchpad_changeset(attrs)
    |> Repo.update()
  end

  def remove_source_history(%Image{} = image) do
    image
    |> Repo.preload(:source_changes)
    |> Image.remove_source_history_changeset()
    |> Repo.update()
  end

  def repair_image(%Image{} = image) do
    Image
    |> where(id: ^image.id)
    |> Repo.update_all(set: [thumbnails_generated: false, processed: false])

    Exq.enqueue(Exq, queue(image.image_mime_type), ThumbnailWorker, [image.id])
  end

  defp queue("video/webm"), do: "videos"
  defp queue(_mime_type), do: "images"

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
  end

  def update_description(%Image{} = image, attrs) do
    image
    |> Image.description_changeset(attrs)
    |> Repo.update()
  end

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
      user_agent: attribution[:user_agent],
      referrer: attribution[:referrer],
      added: added
    }
  end

  def update_locked_tags(%Image{} = image, attrs) do
    new_tags = Tags.get_or_create_tags(attrs["tag_input"])

    image
    |> Repo.preload(:locked_tags)
    |> Image.locked_tags_changeset(attrs, new_tags)
    |> Repo.update()
  end

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
    |> Multi.run(:added_tag_changes, fn repo, %{image: {image, added_tags, _removed}} ->
      tag_changes =
        added_tags
        |> Enum.map(&tag_change_attributes(attribution, image, &1, true, attribution[:user]))

      {count, nil} = repo.insert_all(TagChange, tag_changes)

      {:ok, count}
    end)
    |> Multi.run(:removed_tag_changes, fn repo, %{image: {image, _added, removed_tags}} ->
      tag_changes =
        removed_tags
        |> Enum.map(&tag_change_attributes(attribution, image, &1, false, attribution[:user]))

      {count, nil} = repo.insert_all(TagChange, tag_changes)

      {:ok, count}
    end)
    |> Multi.run(:added_tag_count, fn
      _repo, %{image: {%{hidden_from_users: true}, _added, _removed}} ->
        {:ok, 0}

      repo, %{image: {_image, added_tags, _removed}} ->
        tag_ids = added_tags |> Enum.map(& &1.id)
        tags = Tag |> where([t], t.id in ^tag_ids)

        {count, nil} = repo.update_all(tags, inc: [images_count: 1])

        {:ok, count}
    end)
    |> Multi.run(:removed_tag_count, fn
      _repo, %{image: {%{hidden_from_users: true}, _added, _removed}} ->
        {:ok, 0}

      repo, %{image: {_image, _added, removed_tags}} ->
        tag_ids = removed_tags |> Enum.map(& &1.id)
        tags = Tag |> where([t], t.id in ^tag_ids)

        {count, nil} = repo.update_all(tags, inc: [images_count: -1])

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

  def update_tag_change_limits_after_commit(image, attribution) do
    rating_changed_count = if(image.ratings_changed, do: 1, else: 0)
    tag_changed_count = length(image.added_tags) + length(image.removed_tags)
    user = attribution[:user]
    ip = attribution[:ip]

    Limits.update_tag_count_after_update(user, ip, tag_changed_count)
    Limits.update_rating_count_after_update(user, ip, rating_changed_count)
  end

  defp tag_change_attributes(attribution, image, tag, added, user) do
    now = DateTime.utc_now(:second)

    user_id =
      case user do
        nil -> nil
        user -> user.id
      end

    %{
      image_id: image.id,
      tag_id: tag.id,
      user_id: user_id,
      created_at: now,
      updated_at: now,
      tag_name_cache: tag.name,
      ip: attribution[:ip],
      fingerprint: attribution[:fingerprint],
      user_agent: attribution[:user_agent],
      referrer: attribution[:referrer],
      added: added
    }
  end

  def update_uploader(%Image{} = image, attrs) do
    image
    |> Image.uploader_changeset(attrs)
    |> Repo.update()
  end

  def update_anonymous(%Image{} = image, attrs) do
    image
    |> Image.anonymous_changeset(attrs)
    |> Repo.update()
  end

  def update_hide_reason(%Image{} = image, attrs) do
    image
    |> Image.hide_reason_changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, image} ->
        reindex_image(image)

        {:ok, image}

      error ->
        error
    end
  end

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

  def merge_image(multi \\ nil, %Image{} = image, duplicate_of_image, user) do
    multi = multi || Multi.new()

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
    |> Multi.run(:migrate_sources, fn repo, %{} ->
      {:ok,
       migrate_sources(
         repo.preload(image, [:sources]),
         repo.preload(duplicate_of_image, [:sources])
       )}
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
    |> Repo.transaction()
    |> process_after_hide()
    |> case do
      {:ok, result} ->
        reindex_image(duplicate_of_image)
        Comments.reindex_comments(duplicate_of_image)
        notify_merge(image, duplicate_of_image)

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
      query = where(Tag, [t], t.id in ^tag_ids)

      repo.update_all(query, inc: [images_count: -1])

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

        Comments.reindex_comments(image)
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
        Comments.reindex_comments(image)
        Tags.reindex_tags(tags)

        {:ok, image}

      error ->
        error
    end
  end

  def unhide_image(image), do: {:ok, image}

  def batch_update(image_ids, added_tags, removed_tags, tag_change_attributes) do
    image_ids =
      Image
      |> where([i], i.id in ^image_ids and i.hidden_from_users == false)
      |> select([i], i.id)
      |> Repo.all()

    added_tags = Enum.map(added_tags, & &1.id)
    removed_tags = Enum.map(removed_tags, & &1.id)

    # Change everything in one go, ignoring any validation errors

    # Note: computing the Cartesian product
    insertions =
      for tag_id <- added_tags, image_id <- image_ids do
        %{tag_id: tag_id, image_id: image_id}
      end

    deletions =
      Tagging
      |> where([t], t.image_id in ^image_ids and t.tag_id in ^removed_tags)
      |> select([t], [t.image_id, t.tag_id])

    now = DateTime.utc_now(:second)
    tag_change_attributes = Map.merge(tag_change_attributes, %{created_at: now, updated_at: now})
    tag_attributes = %{name: "", slug: "", created_at: now, updated_at: now}

    Repo.transaction(fn ->
      {_count, inserted} =
        Repo.insert_all(Tagging, insertions,
          on_conflict: :nothing,
          returning: [:image_id, :tag_id]
        )

      {_count, deleted} = Repo.delete_all(deletions)

      inserted = Enum.map(inserted, &[&1.image_id, &1.tag_id])

      added_changes =
        Enum.map(inserted, fn [image_id, tag_id] ->
          Map.merge(tag_change_attributes, %{image_id: image_id, tag_id: tag_id, added: true})
        end)

      removed_changes =
        Enum.map(deleted, fn [image_id, tag_id] ->
          Map.merge(tag_change_attributes, %{image_id: image_id, tag_id: tag_id, added: false})
        end)

      changes = added_changes ++ removed_changes

      Repo.insert_all(TagChange, changes)

      # In order to merge into the existing tables here in one go, insert_all
      # is used with a query that is guaranteed to conflict on every row by
      # using the primary key.

      added_upserts =
        inserted
        |> Enum.group_by(fn [_image_id, tag_id] -> tag_id end)
        |> Enum.map(fn {tag_id, instances} ->
          Map.merge(tag_attributes, %{id: tag_id, images_count: length(instances)})
        end)

      removed_upserts =
        deleted
        |> Enum.group_by(fn [_image_id, tag_id] -> tag_id end)
        |> Enum.map(fn {tag_id, instances} ->
          Map.merge(tag_attributes, %{id: tag_id, images_count: -length(instances)})
        end)

      update_query = update(Tag, inc: [images_count: fragment("EXCLUDED.images_count")])

      upserts = added_upserts ++ removed_upserts

      Repo.insert_all(Tag, upserts, on_conflict: update_query, conflict_target: [:id])
    end)
    |> case do
      {:ok, _} = result ->
        reindex_images(image_ids)
        Tags.reindex_tags(Enum.map(added_tags ++ removed_tags, &%{id: &1}))

        result

      result ->
        result
    end
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

  def user_name_reindex(old_name, new_name) do
    data = ImageIndex.user_name_update_by_query(old_name, new_name)

    Search.update_by_query(Image, data.query, data.set_replacements, data.replacements)
  end

  def reindex_image(%Image{} = image) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Images", "id", [image.id]])

    image
  end

  def reindex_images(image_ids) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Images", "id", image_ids])

    image_ids
  end

  def indexing_preloads do
    [
      :user,
      :favers,
      :downvoters,
      :upvoters,
      :hiders,
      :deleter,
      :gallery_interactions,
      :sources,
      tags: [:aliases, :aliased_tag]
    ]
  end

  def perform_reindex(column, condition) do
    Image
    |> preload(^indexing_preloads())
    |> where([i], field(i, ^column) in ^condition)
    |> Search.reindex(Image)
  end

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

  def perform_purge(files) do
    {_out, 0} = System.cmd("purge-cache", [Jason.encode!(%{files: files})])

    :ok
  end

  alias Philomena.Images.Subscription

  def migrate_subscriptions(source, target) do
    subscriptions =
      Subscription
      |> where(image_id: ^source.id)
      |> select([s], %{image_id: type(^target.id, :integer), user_id: s.user_id})
      |> Repo.all()

    Repo.insert_all(Subscription, subscriptions, on_conflict: :nothing)

    {comment_notification_count, nil} =
      ImageCommentNotification
      |> where(image_id: ^source.id)
      |> Repo.update_all(set: [image_id: target.id])

    {merge_notification_count, nil} =
      ImageMergeNotification
      |> where(target_id: ^source.id)
      |> Repo.update_all(set: [target_id: target.id])

    {:ok, {comment_notification_count, merge_notification_count}}
  end

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

  def notify_merge(source, target) do
    Exq.enqueue(Exq, "notifications", NotificationWorker, ["Images", [source.id, target.id]])
  end

  def perform_notify([source_id, target_id]) do
    source = get_image!(source_id)
    target = get_image!(target_id)

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
