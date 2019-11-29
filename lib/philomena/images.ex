defmodule Philomena.Images do
  @moduledoc """
  The Images context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Images.Image
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.TagChanges.TagChange
  alias Philomena.Tags
  alias Philomena.Tags.Tag
  alias Philomena.Processors
  alias Philomena.Notifications

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
      |> Processors.after_upload(attrs)

    Multi.new
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
    |> Multi.run(:subscribe, fn _repo, %{image: image} ->
      create_subscription(image, attribution[:user])
    end)
    |> Multi.run(:after, fn _repo, %{image: image} ->
      Processors.after_insert(image)

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

    Multi.new
    |> Multi.update(:image, image_changes)
    |> Multi.insert(:source_change, source_changes)
    |> Repo.isolated_transaction(:serializable)
  end

  def update_tags(%Image{} = image, attribution, attrs) do
    old_tags = Tags.get_or_create_tags(attrs["old_tag_input"])
    new_tags = Tags.get_or_create_tags(attrs["tag_input"])

    Multi.new
    |> Multi.run(:image, fn repo, _chg ->
      image
      |> repo.preload(:tags, force: true)
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
    |> Multi.run(:added_tag_count, fn repo, %{image: {_image, added_tags, _removed}} ->
      tag_ids = added_tags |> Enum.map(& &1.id)
      tags = Tag |> where([t], t.id in ^tag_ids)

      {count, nil} = repo.update_all(tags, inc: [images_count: 1])

      {:ok, count}
    end)
    |> Multi.run(:removed_tag_count, fn repo, %{image: {_image, _added, removed_tags}} ->
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
        nil  -> nil
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

  def reindex_image(%Image{} = image) do
    spawn fn ->
      Image
      |> preload(^indexing_preloads())
      |> where(id: ^image.id)
      |> Repo.one()
      |> Image.index_document()
    end

    image
  end

  def indexing_preloads do
    [:user, :favers, :downvoters, :upvoters, :hiders, :deleter, :gallery_interactions, tags: [:aliases, :aliased_tag]]
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

  def clear_notification(image, user) do
    Notifications.delete_unread_notification("Image", image.id, user)
  end
end
