defmodule Philomena.Filters do
  @moduledoc """
  The Filters context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Filters.Filter
  alias Philomena.Elasticsearch
  alias Philomena.Filters.ElasticsearchIndex, as: FilterIndex
  alias Philomena.IndexWorker

  @doc """
  Returns the list of filters.

  ## Examples

      iex> list_filters()
      [%Filter{}, ...]

  """
  def list_filters do
    Repo.all(Filter)
  end

  @doc """
  Returns the default filter.

  ## Examples

      iex> default_filter()
      %Filter{}

  """
  def default_filter do
    Filter
    |> where(system: true, name: "Default")
    |> Repo.one!()
  end

  @doc """
  Gets a single filter.

  Raises `Ecto.NoResultsError` if the Filter does not exist.

  ## Examples

      iex> get_filter!(123)
      %Filter{}

      iex> get_filter!(456)
      ** (Ecto.NoResultsError)

  """
  def get_filter!(id), do: Repo.get!(Filter, id)

  @doc """
  Creates a filter.

  ## Examples

      iex> create_filter(%{field: value})
      {:ok, %Filter{}}

      iex> create_filter(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_filter(user, attrs \\ %{}) do
    %Filter{user_id: user.id}
    |> Filter.creation_changeset(attrs)
    |> Repo.insert()
    |> reindex_after_update()
  end

  @doc """
  Updates a filter.

  ## Examples

      iex> update_filter(filter, %{field: new_value})
      {:ok, %Filter{}}

      iex> update_filter(filter, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_filter(%Filter{} = filter, attrs) do
    filter
    |> Filter.update_changeset(attrs)
    |> Repo.update()
    |> reindex_after_update()
  end

  def make_filter_public(%Filter{} = filter) do
    filter
    |> Filter.public_changeset()
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Deletes a Filter.

  ## Examples

      iex> delete_filter(filter)
      {:ok, %Filter{}}

      iex> delete_filter(filter)
      {:error, %Ecto.Changeset{}}

  """
  def delete_filter(%Filter{} = filter) do
    filter
    |> Filter.deletion_changeset()
    |> Repo.delete()
    |> case do
      {:ok, filter} ->
        unindex_filter(filter)

        {:ok, filter}

      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking filter changes.

  ## Examples

      iex> change_filter(filter)
      %Ecto.Changeset{source: %Filter{}}

  """
  def change_filter(%Filter{} = filter) do
    Filter.changeset(filter, %{})
  end

  def recent_and_user_filters(user) do
    recent_filter_ids =
      [user.current_filter_id | user.recent_filter_ids]
      |> Enum.take(10)

    user_filters =
      Filter
      |> select([f], %{id: f.id, name: f.name, recent: ^"f"})
      |> where(user_id: ^user.id)
      |> limit(10)

    recent_filters =
      Filter
      |> select([f], %{id: f.id, name: f.name, recent: ^"t"})
      |> where([f], f.id in ^recent_filter_ids)

    union_all(recent_filters, ^user_filters)
    |> Repo.all()
    |> Enum.sort_by(fn f ->
      Enum.find_index(user.recent_filter_ids, fn id -> f.id == id end)
    end)
    |> Enum.group_by(
      fn
        %{recent: "t"} -> "Recent Filters"
        _user -> "Your Filters"
      end,
      fn %{id: id, name: name} ->
        [key: name, value: id]
      end
    )
    |> Enum.to_list()
    |> Enum.reverse()
  end

  def hide_tag(filter, tag) do
    hidden_tag_ids = Enum.uniq([tag.id | filter.hidden_tag_ids])

    filter
    |> Filter.hidden_tags_changeset(hidden_tag_ids)
    |> Repo.update()
    |> reindex_after_update()
  end

  def unhide_tag(filter, tag) do
    hidden_tag_ids = filter.hidden_tag_ids -- [tag.id]

    filter
    |> Filter.hidden_tags_changeset(hidden_tag_ids)
    |> Repo.update()
    |> reindex_after_update()
  end

  def spoiler_tag(filter, tag) do
    spoilered_tag_ids = Enum.uniq([tag.id | filter.spoilered_tag_ids])

    filter
    |> Filter.spoilered_tags_changeset(spoilered_tag_ids)
    |> Repo.update()
    |> reindex_after_update()
  end

  def unspoiler_tag(filter, tag) do
    spoilered_tag_ids = filter.spoilered_tag_ids -- [tag.id]

    filter
    |> Filter.spoilered_tags_changeset(spoilered_tag_ids)
    |> Repo.update()
    |> reindex_after_update()
  end

  defp reindex_after_update({:ok, filter}) do
    reindex_filter(filter)

    {:ok, filter}
  end

  defp reindex_after_update(error) do
    error
  end

  def user_name_reindex(old_name, new_name) do
    data = FilterIndex.user_name_update_by_query(old_name, new_name)

    Elasticsearch.update_by_query(Filter, data.query, data.set_replacements, data.replacements)
  end

  def reindex_filter(%Filter{} = filter) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Filters", "id", [filter.id]])

    filter
  end

  def unindex_filter(%Filter{} = filter) do
    Elasticsearch.delete_document(filter.id, Filter)

    filter
  end

  def indexing_preloads do
    [:user]
  end

  def perform_reindex(column, condition) do
    Filter
    |> preload(^indexing_preloads())
    |> where([f], field(f, ^column) in ^condition)
    |> Elasticsearch.reindex(Filter)
  end
end
