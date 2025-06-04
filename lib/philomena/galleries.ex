defmodule Philomena.Galleries do
  @moduledoc """
  The Galleries context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias PhilomenaQuery.Search
  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries.Interaction
  alias Philomena.Galleries.SearchIndex, as: GalleryIndex
  alias Philomena.IndexWorker
  alias Philomena.GalleryReorderWorker
  alias Philomena.Notifications
  alias Philomena.Images

  use Philomena.Subscriptions,
    on_delete: :clear_gallery_notification,
    id_name: :gallery_id

  @doc """
  Gets a single gallery.

  Raises `Ecto.NoResultsError` if the Gallery does not exist.

  ## Examples

      iex> get_gallery!(123)
      %Gallery{}

      iex> get_gallery!(456)
      ** (Ecto.NoResultsError)

  """
  def get_gallery!(id), do: Repo.get!(Gallery, id)

  @doc """
  Creates a gallery.

  ## Examples

      iex> create_gallery(%{field: value})
      {:ok, %Gallery{}}

      iex> create_gallery(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_gallery(user, attrs \\ %{}) do
    %Gallery{}
    |> Gallery.creation_changeset(attrs, user)
    |> Repo.insert()
    |> reindex_after_update()
  end

  @doc """
  Updates a gallery.

  ## Examples

      iex> update_gallery(gallery, %{field: new_value})
      {:ok, %Gallery{}}

      iex> update_gallery(gallery, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_gallery(%Gallery{} = gallery, attrs) do
    gallery
    |> Gallery.changeset(attrs)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Deletes a Gallery.

  ## Examples

      iex> delete_gallery(gallery)
      {:ok, %Gallery{}}

      iex> delete_gallery(gallery)
      {:error, %Ecto.Changeset{}}

  """
  def delete_gallery(%Gallery{} = gallery) do
    images =
      Interaction
      |> where(gallery_id: ^gallery.id)
      |> select([i], i.image_id)
      |> Repo.all()

    Multi.new()
    |> Multi.delete(:gallery, gallery)
    |> Repo.transaction()
    |> case do
      {:ok, %{gallery: gallery}} ->
        unindex_gallery(gallery)
        Images.reindex_images(images)

        {:ok, gallery}

      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking gallery changes.

  ## Examples

      iex> change_gallery(gallery)
      %Ecto.Changeset{source: %Gallery{}}

  """
  def change_gallery(%Gallery{} = gallery) do
    Gallery.changeset(gallery, %{})
  end

  @doc """
  Updates gallery search indices when a user's name changes.

  ## Examples

      iex> user_name_reindex("old_username", "new_username")
      :ok

  """
  def user_name_reindex(old_name, new_name) do
    data = GalleryIndex.user_name_update_by_query(old_name, new_name)

    Search.update_by_query(Gallery, data.query, data.set_replacements, data.replacements)
  end

  defp reindex_after_update({:ok, gallery}) do
    reindex_gallery(gallery)

    {:ok, gallery}
  end

  defp reindex_after_update(error) do
    error
  end

  @doc """
  Queues a gallery for reindexing.

  Adds the gallery to the indexing queue to update its search index.

  ## Examples

      iex> reindex_gallery(gallery)
      %Gallery{}

  """
  def reindex_gallery(%Gallery{} = gallery) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Galleries", "id", [gallery.id]])

    gallery
  end

  @doc """
  Removes a gallery from the search index.

  Deletes the gallery's document from the search index.

  ## Examples

      iex> unindex_gallery(gallery)
      %Gallery{}

  """
  def unindex_gallery(%Gallery{} = gallery) do
    Search.delete_document(gallery.id, Gallery)

    gallery
  end

  @doc """
  Returns a list of associations to preload when indexing galleries.

  ## Examples

      iex> indexing_preloads()
      [:subscribers, :creator, :interactions]

  """
  def indexing_preloads do
    [:subscribers, :creator, :interactions]
  end

  @doc """
  Reindexes galleries based on a column condition.

  Updates the search index for all galleries matching the given column condition.
  Used for batch reindexing of galleries.

  ## Examples

      iex> perform_reindex(:id, [1, 2, 3])
      {:ok, [%Gallery{}, ...]}

  """
  def perform_reindex(column, condition) do
    Gallery
    |> preload(^indexing_preloads())
    |> where([g], field(g, ^column) in ^condition)
    |> Search.reindex(Gallery)
  end

  @doc """
  Adds the specified image to the gallery, updates image count, triggers
  notifications, and performs necessary reindexing.

  The image is added at the last position.

  ## Examples

      iex> add_image_to_gallery(gallery, image)
      {:ok,
       %{
         gallery: %Gallery{},
         interaction: %Interaction{},
         image_count: 1,
         notification: %Notification{}
       }}

  """
  def add_image_to_gallery(gallery, image) do
    Multi.new()
    |> Multi.run(:gallery, fn repo, %{} ->
      gallery =
        Gallery
        |> where(id: ^gallery.id)
        |> lock("FOR UPDATE")
        |> repo.one()

      {:ok, gallery}
    end)
    |> Multi.run(:interaction, fn repo, %{} ->
      position = (last_position(gallery.id) || -1) + 1

      %Interaction{gallery_id: gallery.id}
      |> Interaction.changeset(%{"image_id" => image.id, "position" => position})
      |> repo.insert()
    end)
    |> Multi.run(:image_count, fn repo, %{} ->
      now = DateTime.utc_now()

      {count, nil} =
        Gallery
        |> where(id: ^gallery.id)
        |> repo.update_all(inc: [image_count: 1], set: [updated_at: now])

      {:ok, count}
    end)
    |> Multi.run(:notification, &notify_gallery/2)
    |> Repo.transaction()
    |> case do
      {:ok, result} ->
        Images.reindex_image(image)
        reindex_gallery(gallery)

        {:ok, result}

      error ->
        error
    end
  end

  @doc """
  Removes the specified image from the gallery, updates image count,
  and performs necessary reindexing.

  ## Examples

      iex> remove_image_from_gallery(gallery, image)
      {:ok,
       %{
         gallery: %Gallery{},
         interaction: 1,
         image_count: 0
       }}

  """
  def remove_image_from_gallery(gallery, image) do
    Multi.new()
    |> Multi.run(:gallery, fn repo, %{} ->
      gallery =
        Gallery
        |> where(id: ^gallery.id)
        |> lock("FOR UPDATE")
        |> repo.one()

      {:ok, gallery}
    end)
    |> Multi.run(:interaction, fn repo, %{} ->
      {count, nil} =
        Interaction
        |> where(gallery_id: ^gallery.id, image_id: ^image.id)
        |> repo.delete_all()

      {:ok, count}
    end)
    |> Multi.run(:image_count, fn repo, %{interaction: interaction_count} ->
      now = DateTime.utc_now()

      {count, nil} =
        Gallery
        |> where(id: ^gallery.id)
        |> repo.update_all(inc: [image_count: -interaction_count], set: [updated_at: now])

      {:ok, count}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, result} ->
        Images.reindex_image(image)
        reindex_gallery(gallery)

        {:ok, result}

      error ->
        error
    end
  end

  defp notify_gallery(_repo, %{gallery: gallery}) do
    Notifications.create_gallery_image_notification(gallery)
  end

  defp last_position(gallery_id) do
    Interaction
    |> where(gallery_id: ^gallery_id)
    |> Repo.aggregate(:max, :position)
  end

  @doc """
  Queues a gallery reorder operation.
  Returns the gallery struct unchanged, for use in a pipeline.

  ## Examples

      iex> reorder_gallery(gallery, [1, 2, 3])
      %Gallery{}

  """
  def reorder_gallery(gallery, image_ids) do
    Exq.enqueue(Exq, "indexing", GalleryReorderWorker, [gallery.id, image_ids])

    gallery
  end

  @doc """
  Performs the actual reordering of images in a gallery.

  Reorders the gallery's images according to the provided image IDs list, updating
  positions while maintaining relative order for unspecified images. Handles position
  updates efficiently and reindexes only the affected images.

  ## Examples

      iex> perform_reorder(gallery_id, [3, 1, 2])
      :ok

  """
  def perform_reorder(gallery_id, image_ids) do
    gallery = get_gallery!(gallery_id)

    interactions =
      Interaction
      |> where([gi], gi.image_id in ^image_ids and gi.gallery_id == ^gallery.id)
      |> order_by(^position_order(gallery))
      |> Repo.all()

    interaction_positions =
      interactions
      |> Enum.with_index()
      |> Map.new(fn {interaction, index} -> {index, interaction.position} end)

    images_present = Map.new(interactions, &{&1.image_id, true})

    requested =
      image_ids
      |> Enum.filter(&images_present[&1])
      |> Enum.with_index()
      |> Map.new()

    changes =
      interactions
      |> Enum.with_index()
      |> Enum.flat_map(fn {interaction, current_index} ->
        new_index = requested[interaction.image_id]

        if new_index == current_index do
          []
        else
          [
            [
              id: interaction.id,
              position: interaction_positions[new_index]
            ]
          ]
        end
      end)

    changes
    |> Enum.each(fn change ->
      id = Keyword.fetch!(change, :id)
      change = Keyword.delete(change, :id)

      Interaction
      |> where([i], i.id == ^id)
      |> Repo.update_all(set: change)
    end)

    # Do the update in a single statement
    # Repo.insert_all(
    #   Interaction,
    #   changes,
    #   on_conflict: {:replace, [:position]},
    #   conflict_target: [:id]
    # )

    # Now update all the associated images
    Images.reindex_images(Map.keys(requested))

    :ok
  end

  defp position_order(%{order_position_asc: true}), do: [asc: :position]
  defp position_order(_gallery), do: [desc: :position]

  @doc """
  Removes all gallery notifications for a given gallery and user.

  ## Examples

      iex> clear_gallery_notification(gallery, user)
      :ok

  """
  def clear_gallery_notification(%Gallery{} = gallery, user) do
    Notifications.clear_gallery_image_notification(gallery, user)
    :ok
  end
end
