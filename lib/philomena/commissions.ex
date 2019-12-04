defmodule Philomena.Commissions do
  @moduledoc """
  The Commissions context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Commissions.Commission

  @doc """
  Returns the list of commissions.

  ## Examples

      iex> list_commissions()
      [%Commission{}, ...]

  """
  def list_commissions do
    Repo.all(Commission)
  end

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

  alias Philomena.Commissions.Item

  @doc """
  Returns the list of commission_items.

  ## Examples

      iex> list_commission_items()
      [%Item{}, ...]

  """
  def list_commission_items do
    Repo.all(Item)
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
    Ecto.build_assoc(commission, :items)
    |> Item.changeset(attrs)
    |> Repo.insert()
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
    Repo.delete(item)
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
