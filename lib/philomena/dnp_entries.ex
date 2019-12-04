defmodule Philomena.DnpEntries do
  @moduledoc """
  The DnpEntries context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.DnpEntries.DnpEntry

  @doc """
  Returns the list of dnp_entries.

  ## Examples

      iex> list_dnp_entries()
      [%DnpEntry{}, ...]

  """
  def list_dnp_entries do
    Repo.all(DnpEntry)
  end

  @doc """
  Gets a single dnp_entry.

  Raises `Ecto.NoResultsError` if the Dnp entry does not exist.

  ## Examples

      iex> get_dnp_entry!(123)
      %DnpEntry{}

      iex> get_dnp_entry!(456)
      ** (Ecto.NoResultsError)

  """
  def get_dnp_entry!(id), do: Repo.get!(DnpEntry, id)

  @doc """
  Creates a dnp_entry.

  ## Examples

      iex> create_dnp_entry(%{field: value})
      {:ok, %DnpEntry{}}

      iex> create_dnp_entry(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_dnp_entry(attrs \\ %{}) do
    %DnpEntry{}
    |> DnpEntry.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a dnp_entry.

  ## Examples

      iex> update_dnp_entry(dnp_entry, %{field: new_value})
      {:ok, %DnpEntry{}}

      iex> update_dnp_entry(dnp_entry, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_dnp_entry(%DnpEntry{} = dnp_entry, attrs) do
    dnp_entry
    |> DnpEntry.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a DnpEntry.

  ## Examples

      iex> delete_dnp_entry(dnp_entry)
      {:ok, %DnpEntry{}}

      iex> delete_dnp_entry(dnp_entry)
      {:error, %Ecto.Changeset{}}

  """
  def delete_dnp_entry(%DnpEntry{} = dnp_entry) do
    Repo.delete(dnp_entry)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking dnp_entry changes.

  ## Examples

      iex> change_dnp_entry(dnp_entry)
      %Ecto.Changeset{source: %DnpEntry{}}

  """
  def change_dnp_entry(%DnpEntry{} = dnp_entry) do
    DnpEntry.changeset(dnp_entry, %{})
  end

  def count_dnp_entries() do
    DnpEntry
    |> where([dnp], dnp.aasm_state in [ "requested", "claimed", "acknowledged" ])
    |> Repo.aggregate(:count, :id)
  end
end
