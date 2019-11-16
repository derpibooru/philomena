defmodule Philomena.SourceChanges do
  @moduledoc """
  The SourceChanges context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.SourceChanges.SourceChange

  @doc """
  Returns the list of source_changes.

  ## Examples

      iex> list_source_changes()
      [%SourceChange{}, ...]

  """
  def list_source_changes do
    Repo.all(SourceChange)
  end

  @doc """
  Gets a single source_change.

  Raises `Ecto.NoResultsError` if the Source change does not exist.

  ## Examples

      iex> get_source_change!(123)
      %SourceChange{}

      iex> get_source_change!(456)
      ** (Ecto.NoResultsError)

  """
  def get_source_change!(id), do: Repo.get!(SourceChange, id)

  @doc """
  Creates a source_change.

  ## Examples

      iex> create_source_change(%{field: value})
      {:ok, %SourceChange{}}

      iex> create_source_change(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_source_change(attrs \\ %{}) do
    %SourceChange{}
    |> SourceChange.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a source_change.

  ## Examples

      iex> update_source_change(source_change, %{field: new_value})
      {:ok, %SourceChange{}}

      iex> update_source_change(source_change, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_source_change(%SourceChange{} = source_change, attrs) do
    source_change
    |> SourceChange.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a SourceChange.

  ## Examples

      iex> delete_source_change(source_change)
      {:ok, %SourceChange{}}

      iex> delete_source_change(source_change)
      {:error, %Ecto.Changeset{}}

  """
  def delete_source_change(%SourceChange{} = source_change) do
    Repo.delete(source_change)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking source_change changes.

  ## Examples

      iex> change_source_change(source_change)
      %Ecto.Changeset{source: %SourceChange{}}

  """
  def change_source_change(%SourceChange{} = source_change) do
    SourceChange.changeset(source_change, %{})
  end
end
