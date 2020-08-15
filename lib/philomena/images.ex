defmodule Philomena.Images do
  @moduledoc """
  The Images context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Elasticsearch
  alias Philomena.ThumbnailWorker
  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Images.Image
  alias Philomena.Images.Hider
  alias Philomena.Images.Uploader
  alias Philomena.Images.Tagging
  alias Philomena.Images.ElasticsearchIndex, as: ImageIndex
  alias Philomena.ImageFeatures.ImageFeature
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.TagChanges.TagChange
  alias Philomena.Tags
  alias Philomena.UserStatistics
  alias Philomena.Tags.Tag
  alias Philomena.Notifications
  alias Philomena.Interactions
  alias Philomena.Reports.Report
  alias Philomena.Comments

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
  Creates a image.

  ## Examples

      iex> create_image(%{field: value})
      {:ok, %Image{}}

      iex> create_image(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_image(attribution, attrs \\ %{}) do
    tags = Tags.get_or_create_tags(attrs["tag_input"])

    image =
      %Image{}
      |> Image.creation_changeset(attrs, attribution)
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
    |> Multi.run(:source_change, fn repo, %{image: image} ->
      %SourceChange{image_id: image.id, initial: true}
      |> SourceChange.creation_changeset(attrs, attribution)
      |> repo.insert()
    end)
    |> Multi.run(:added_tag_count, fn repo, %{image: image} ->
      tag_ids = image.added_tags |> Enum.map(& &1.id)
      tags = Tag |> where([t], t.id in ^tag_ids)

      {count, nil} = repo.update_all(tags, inc: [images_count: 1])

      {:ok, count}
    end)
    |> Multi.run(:subscribe, fn _repo, %{image: image} ->
      create_subscription(image, attribution[:user])
    end)
    |> Multi.run(:after, fn _repo, %{image: image} ->
      Uploader.persist_upload(image)
      Uploader.unpersist_old_upload(image)

      {:ok, nil}
    end)
    |> Repo.isolated_transaction(:serializable)
    |> case do
      {:ok, %{image: image}} = result ->
        repair_image(image)
        reindex_image(image)
        Tags.reindex_tags(image.added_tags)
        UserStatistics.inc_stat(attribution[:user], :uploads)

        result

      result ->
        result
    end
  end

  def feature_image(featurer, %Image{} = image) do
    image = Repo.preload(image, :tags)
    [featured] = Tags.get_or_create_tags("featured image")

    feature =
      %ImageFeature{user_id: featurer.id, image_id: image.id}
      |> ImageFeature.changeset(%{})

    image =
      image
      |> Image.tag_changeset(%{}, image.tags, [featured | image.tags])
      |> Image.cache_changeset()

    Multi.new()
    |> Multi.insert(:feature, feature)
    |> Multi.update(:image, image)
    |> Multi.run(:added_tag_count, fn repo, %{image: image} ->
      tag_ids = image.added_tags |> Enum.map(& &1.id)
      tags = Tag |> where([t], t.id in ^tag_ids)

      {count, nil} = repo.update_all(tags, inc: [images_count: 1])

      {:ok, count}
    end)
    |> Repo.isolated_transaction(:serializable)
  end

  def destroy_image(%Image{} = image) do
    changeset = Image.remove_image_changeset(image)

    Multi.new()
    |> Multi.update(:image, changeset)
    |> Multi.run(:remove_file, fn _repo, %{image: image} ->
      Uploader.unpersist_old_upload(image)
      Hider.destroy_thumbnails(image)

      {:ok, nil}
    end)
    |> Repo.isolated_transaction(:serializable)
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
    image =
      image
      |> Image.changeset(attrs)
      |> Uploader.analyze_upload(attrs)

    Multi.new()
    |> Multi.update(:image, image)
    |> Multi.run(:after, fn _repo, %{image: image} ->
      Uploader.persist_upload(image)
      Uploader.unpersist_old_upload(image)

      {:ok, nil}
    end)
    |> Repo.isolated_transaction(:serializable)
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

  def update_source(%Image{} = image, attribution, attrs) do
    image_changes =
      image
      |> Image.source_changeset(attrs)

    source_changes =
      Ecto.build_assoc(image, :source_changes)
      |> SourceChange.creation_changeset(attrs, attribution)

    Multi.new()
    |> Multi.update(:image, image_changes)
    |> Multi.run(:source_change, fn repo, _changes ->
      case image_changes.changes do
        %{source_url: _new_source} ->
          repo.insert(source_changes)

        _ ->
          {:ok, nil}
      end
    end)
    |> Repo.isolated_transaction(:serializable)
  end

  def update_tags(%Image{} = image, attribution, attrs) do
    old_tags = Tags.get_or_create_tags(attrs["old_tag_input"])
    new_tags = Tags.get_or_create_tags(attrs["tag_input"])

    Multi.new()
    |> Multi.run(:image, fn repo, _chg ->
      image
      |> repo.preload(:tags)
      |> Image.tag_changeset(%{}, old_tags, new_tags)
      |> repo.update()
      |> case do
        {:ok, image} ->
          {:ok, {image, image.added_tags, image.removed_tags}}

        error ->
          error
      end
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
    |> Repo.isolated_transaction(:serializable)
  end

  defp tag_change_attributes(attribution, image, tag, added, user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

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

  def hide_image(%Image{} = image, user, attrs) do
    DuplicateReport
    |> where(state: "open")
    |> where([d], d.image_id == ^image.id or d.duplicate_of_image_id == ^image.id)
    |> Repo.update_all(set: [state: "rejected"])

    Image.hide_changeset(image, attrs, user)
    |> internal_hide_image(image)
  end

  def update_hide_reason(%Image{} = image, attrs) do
    image
    |> Image.hide_reason_changeset(attrs)
    |> Repo.update()
  end

  def merge_image(%Image{} = image, duplicate_of_image) do
    result =
      Image.merge_changeset(image, duplicate_of_image)
      |> internal_hide_image(image)

    case result do
      {:ok, changes} ->
        update_first_seen_at(
          duplicate_of_image,
          image.first_seen_at,
          duplicate_of_image.first_seen_at
        )

        tags = Tags.copy_tags(image, duplicate_of_image)
        Comments.migrate_comments(image, duplicate_of_image)
        Interactions.migrate_interactions(image, duplicate_of_image)

        {:ok, %{changes | tags: changes.tags ++ tags}}

      _error ->
        result
    end
  end

  defp update_first_seen_at(image, time_1, time_2) do
    min_time =
      case NaiveDateTime.compare(time_1, time_2) do
        :gt -> time_2
        _ -> time_1
      end

    Image
    |> where(id: ^image.id)
    |> Repo.update_all(set: [first_seen_at: min_time])
  end

  defp internal_hide_image(changeset, image) do
    reports =
      Report
      |> where(reportable_type: "Image", reportable_id: ^image.id)
      |> select([r], r.id)
      |> update(set: [open: false, state: "closed"])

    Multi.new()
    |> Multi.update(:image, changeset)
    |> Multi.update_all(:reports, reports, [])
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
    |> Multi.run(:file, fn _repo, %{image: image} ->
      Hider.hide_thumbnails(image, image.hidden_image_key)

      {:ok, nil}
    end)
    |> Repo.isolated_transaction(:serializable)
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
    |> Multi.run(:file, fn _repo, %{image: image} ->
      Hider.unhide_thumbnails(image, key)

      {:ok, nil}
    end)
    |> Repo.isolated_transaction(:serializable)
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

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
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

    Elasticsearch.update_by_query(Image, data.query, data.set_replacements, data.replacements)
  end

  def reindex_image(%Image{} = image) do
    reindex_images([image.id])

    image
  end

  def reindex_images(image_ids) do
    spawn(fn ->
      Image
      |> preload(^indexing_preloads())
      |> where([i], i.id in ^image_ids)
      |> Elasticsearch.reindex(Image)
    end)

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
      tags: [:aliases, :aliased_tag]
    ]
  end

  alias Philomena.Images.Subscription

  def subscribed?(_image, nil), do: false

  def subscribed?(image, user) do
    Subscription
    |> where(image_id: ^image.id, user_id: ^user.id)
    |> Repo.exists?()
  end

  @doc """
  Creates a subscription.

  ## Examples

      iex> create_subscription(%{field: value})
      {:ok, %Subscription{}}

      iex> create_subscription(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_subscription(_image, nil), do: {:ok, nil}

  def create_subscription(image, user) do
    %Subscription{image_id: image.id, user_id: user.id}
    |> Subscription.changeset(%{})
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc """
  Deletes a Subscription.

  ## Examples

      iex> delete_subscription(subscription)
      {:ok, %Subscription{}}

      iex> delete_subscription(subscription)
      {:error, %Ecto.Changeset{}}

  """
  def delete_subscription(image, user) do
    clear_notification(image, user)

    %Subscription{image_id: image.id, user_id: user.id}
    |> Repo.delete()
  end

  def clear_notification(_image, nil), do: nil

  def clear_notification(image, user) do
    Notifications.delete_unread_notification("Image", image.id, user)
  end
end
