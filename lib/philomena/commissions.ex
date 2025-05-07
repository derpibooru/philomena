defmodule Philomena.Commissions do
  @moduledoc """
  The Commissions context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Commissions.Commission
  alias Philomena.Commissions.Item
  alias Philomena.Commissions.QueryBuilder
  alias Philomena.Commissions.SearchQuery

  @doc """
  Gets a single commission.

  Raises `Ecto.NoResultsError` if the Commission does not exist.

  ## Examples

      iex> get_commission!(123)
      %Commission{}

      iex> get_commission!(456)
      ** (Ecto.NoResultsError)

  """
  def get_commission!(id), do: Repo.get!(Commission, id)

  @doc """
  Creates a commission.

  ## Examples

      iex> create_commission(%{field: value})
      {:ok, %Commission{}}

      iex> create_commission(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_commission(user, attrs \\ %{}) do
    Ecto.build_assoc(user, :commission)
    |> Commission.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a commission.

  ## Examples

      iex> update_commission(commission, %{field: new_value})
      {:ok, %Commission{}}

      iex> update_commission(commission, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_commission(%Commission{} = commission, attrs) do
    commission
    |> Commission.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Commission.

  ## Examples

      iex> delete_commission(commission)
      {:ok, %Commission{}}

      iex> delete_commission(commission)
      {:error, %Ecto.Changeset{}}

  """
  def delete_commission(%Commission{} = commission) do
    Repo.delete(commission)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking commission changes.

  ## Examples

      iex> change_commission(commission)
      %Ecto.Changeset{source: %Commission{}}

  """
  def change_commission(%Commission{} = commission) do
    Commission.changeset(commission, %{})
  end

  @doc """
  Searches commissions based on the given parameters.

  ## Parameters

    * params - Map of optional search parameters:
      * item_type - Filter by item type
      * category - Filter by category
      * keywords - Search in information and will_create fields
      * price_min - Minimum base price
      * price_max - Maximum base price

  Returns `{:ok, query}` with a queryable that can be used with Repo.paginate/2,
  or `{:error, changeset}` if the provided parameters are invalid.
  """
  def execute_search_query(params \\ %{}) do
    QueryBuilder.search_commissions(params)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking search query changes.

  ## Examples

      iex> change_search_query(search_query)
      %Ecto.Changeset{source: %SearchQuery{}}

  """
  def change_search_query(%SearchQuery{} = search_query) do
    SearchQuery.changeset(search_query, %{})
  end

  @doc """
  Gets a single item.

  Raises `Ecto.NoResultsError` if the Item does not exist.

  ## Examples

      iex> get_item!(123)
      %Item{}

      iex> get_item!(456)
      ** (Ecto.NoResultsError)

  """
  def get_item!(id), do: Repo.get!(Item, id)

  @doc """
  Creates a item.

  ## Examples

      iex> create_item(%{field: value})
      {:ok, %Item{}}

      iex> create_item(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_item(commission, attrs \\ %{}) do
    changeset =
      Ecto.build_assoc(commission, :items)
      |> Item.changeset(attrs)

    update =
      Commission
      |> where(id: ^commission.id)
      |> update(inc: [commission_items_count: 1])

    Multi.new()
    |> Multi.insert(:item, changeset)
    |> Multi.update_all(:commission, update, [])
    |> Repo.transaction()
    |> case do
      {:error, :item, changeset, _} ->
        {:error, changeset}

      result ->
        result
    end
  end

  @doc """
  Updates a item.

  ## Examples

      iex> update_item(item, %{field: new_value})
      {:ok, %Item{}}

      iex> update_item(item, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_item(%Item{} = item, attrs) do
    item
    |> Item.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Item.

  ## Examples

      iex> delete_item(item)
      {:ok, %Item{}}

      iex> delete_item(item)
      {:error, %Ecto.Changeset{}}

  """
  def delete_item(%Item{} = item) do
    update =
      Commission
      |> where(id: ^item.commission_id)
      |> update(inc: [commission_items_count: -1])

    Multi.new()
    |> Multi.delete(:item, item)
    |> Multi.update_all(:commission, update, [])
    |> Repo.transaction()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking item changes.

  ## Examples

      iex> change_item(item)
      %Ecto.Changeset{source: %Item{}}

  """
  def change_item(%Item{} = item) do
    Item.changeset(item, %{})
  end
end
