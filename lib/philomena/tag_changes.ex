defmodule Philomena.TagChanges do
  @moduledoc """
  The TagChanges context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.TagChanges.TagChange
  alias Philomena.Images.Tagging
  alias Philomena.Tags.Tag
  alias Philomena.Images

  # TODO: this is substantially similar to Images.batch_update/4.
  # Perhaps it should be extracted.
  def mass_revert(ids, attributes) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    tag_change_attributes = Map.merge(attributes, %{created_at: now, updated_at: now})
    tag_attributes = %{name: "", slug: "", created_at: now, updated_at: now}

    tag_changes =
      TagChange
      |> join(:inner, [tc], _ in assoc(tc, :image))
      |> where([tc, i], tc.id in ^ids and i.hidden_from_users == false)
      |> order_by(desc: :created_at)
      |> Repo.all()
      |> Enum.reject(&is_nil(&1.tag_id))
      |> Enum.uniq_by(&{&1.image_id, &1.tag_id})

    {added, removed} = Enum.split_with(tag_changes, & &1.added)

    image_ids =
      tag_changes
      |> Enum.map(& &1.image_id)
      |> Enum.uniq()

    to_remove =
      added
      |> Enum.map(&{&1.image_id, &1.tag_id})
      |> Enum.reduce(where(Tagging, fragment("'t' = 'f'")), fn {image_id, tag_id}, q ->
        or_where(q, image_id: ^image_id, tag_id: ^tag_id)
      end)
      |> select([t], [t.image_id, t.tag_id])

    to_add = Enum.map(removed, &%{image_id: &1.image_id, tag_id: &1.tag_id})

    Repo.transaction(fn ->
      {_count, inserted} =
        Repo.insert_all(Tagging, to_add, on_conflict: :nothing, returning: [:image_id, :tag_id])

      {_count, deleted} = Repo.delete_all(to_remove)

      inserted = Enum.map(inserted, &[&1.image_id, &1.tag_id])

      added_changes =
        Enum.map(inserted, fn [image_id, tag_id] ->
          Map.merge(tag_change_attributes, %{image_id: image_id, tag_id: tag_id, added: true})
        end)

      removed_changes =
        Enum.map(deleted, fn [image_id, tag_id] ->
          Map.merge(tag_change_attributes, %{image_id: image_id, tag_id: tag_id, added: false})
        end)

      Repo.insert_all(TagChange, added_changes ++ removed_changes)

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
      {:ok, _result} ->
        Images.reindex_images(image_ids)

        {:ok, tag_changes}

      error ->
        error
    end
  end

  @doc """
  Gets a single tag_change.

  Raises `Ecto.NoResultsError` if the Tag change does not exist.

  ## Examples

      iex> get_tag_change!(123)
      %TagChange{}

      iex> get_tag_change!(456)
      ** (Ecto.NoResultsError)

  """
  def get_tag_change!(id), do: Repo.get!(TagChange, id)

  @doc """
  Creates a tag_change.

  ## Examples

      iex> create_tag_change(%{field: value})
      {:ok, %TagChange{}}

      iex> create_tag_change(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_tag_change(attrs \\ %{}) do
    %TagChange{}
    |> TagChange.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tag_change.

  ## Examples

      iex> update_tag_change(tag_change, %{field: new_value})
      {:ok, %TagChange{}}

      iex> update_tag_change(tag_change, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_tag_change(%TagChange{} = tag_change, attrs) do
    tag_change
    |> TagChange.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a TagChange.

  ## Examples

      iex> delete_tag_change(tag_change)
      {:ok, %TagChange{}}

      iex> delete_tag_change(tag_change)
      {:error, %Ecto.Changeset{}}

  """
  def delete_tag_change(%TagChange{} = tag_change) do
    Repo.delete(tag_change)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tag_change changes.

  ## Examples

      iex> change_tag_change(tag_change)
      %Ecto.Changeset{source: %TagChange{}}

  """
  def change_tag_change(%TagChange{} = tag_change) do
    TagChange.changeset(tag_change, %{})
  end
end
