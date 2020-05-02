defmodule Philomena.Galleries do
  @moduledoc """
  The Galleries context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Elasticsearch
  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries.Interaction
  alias Philomena.Galleries.ElasticsearchIndex, as: GalleryIndex
  alias Philomena.Notifications
  alias Philomena.Images

  @doc """
  Returns the list of galleries.

  ## Examples

      iex> list_galleries()
      [%Gallery{}, ...]

  """
  def list_galleries do
    Repo.all(Gallery)
  end

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

    Repo.delete(gallery)
    |> case do
      {:ok, gallery} ->
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

  def user_name_reindex(old_name, new_name) do
    data = GalleryIndex.user_name_update_by_query(old_name, new_name)

    Elasticsearch.update_by_query(Gallery, data.query, data.set_replacements, data.replacements)
  end

  def reindex_gallery(%Gallery{} = gallery) do
    spawn(fn ->
      Gallery
      |> preload(^indexing_preloads())
      |> where(id: ^gallery.id)
      |> Repo.one()
      |> Elasticsearch.index_document(Gallery)
    end)

    gallery
  end

  def unindex_gallery(%Gallery{} = gallery) do
    spawn(fn ->
      Elasticsearch.delete_document(gallery.id, Gallery)
    end)

    gallery
  end

  def indexing_preloads do
    [:subscribers, :creator, :interactions]
  end

  def add_image_to_gallery(gallery, image) do
    Multi.new()
    |> Multi.run(:interaction, fn repo, %{} ->
      position = (last_position(gallery.id) || -1) + 1

      %Interaction{gallery_id: gallery.id}
      |> Interaction.changeset(%{"image_id" => image.id, "position" => position})
      |> repo.insert()
    end)
    |> Multi.run(:gallery, fn repo, %{} ->
      now = DateTime.utc_now()

      {count, nil} =
        Gallery
        |> where(id: ^gallery.id)
        |> repo.update_all(inc: [image_count: 1], set: [updated_at: now])

      {:ok, count}
    end)
    |> Repo.isolated_transaction(:serializable)
  end

  def remove_image_from_gallery(gallery, image) do
    Multi.new()
    |> Multi.run(:interaction, fn repo, %{} ->
      {count, nil} =
        Interaction
        |> where(gallery_id: ^gallery.id, image_id: ^image.id)
        |> repo.delete_all()

      {:ok, count}
    end)
    |> Multi.run(:gallery, fn repo, %{interaction: interaction_count} ->
      now = DateTime.utc_now()

      {count, nil} =
        Gallery
        |> where(id: ^gallery.id)
        |> repo.update_all(inc: [image_count: -interaction_count], set: [updated_at: now])

      {:ok, count}
    end)
    |> Repo.isolated_transaction(:serializable)
  end

  defp last_position(gallery_id) do
    Interaction
    |> where(gallery_id: ^gallery_id)
    |> Repo.aggregate(:max, :position)
  end

  def notify_gallery(gallery) do
    spawn(fn ->
      subscriptions =
        gallery
        |> Repo.preload(:subscriptions)
        |> Map.fetch!(:subscriptions)

      Notifications.notify(
        gallery,
        subscriptions,
        %{
          actor_id: gallery.id,
          actor_type: "Gallery",
          actor_child_id: nil,
          actor_child_type: nil,
          action: "added images to"
        }
      )
    end)

    gallery
  end

  def reorder_gallery(gallery, image_ids) do
    spawn(fn ->
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

          case new_index == current_index do
            true ->
              []

            false ->
              [
                [
                  id: interaction.id,
                  position: interaction_positions[new_index]
                ]
              ]
          end
        end)

      changes
      |> Enum.map(fn change ->
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
    end)

    gallery
  end

  defp position_order(%{order_position_asc: true}), do: [asc: :position]
  defp position_order(_gallery), do: [desc: :position]

  alias Philomena.Galleries.Subscription

  def subscribed?(_gallery, nil), do: false

  def subscribed?(gallery, user) do
    Subscription
    |> where(gallery_id: ^gallery.id, user_id: ^user.id)
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
  def create_subscription(gallery, user) do
    %Subscription{gallery_id: gallery.id, user_id: user.id}
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
  def delete_subscription(gallery, user) do
    %Subscription{gallery_id: gallery.id, user_id: user.id}
    |> Repo.delete()
  end

  def clear_notification(_gallery, nil), do: nil

  def clear_notification(gallery, user) do
    Notifications.delete_unread_notification("Gallery", gallery.id, user)
  end
end
