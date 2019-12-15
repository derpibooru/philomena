defmodule Philomena.ModNotes do
  @moduledoc """
  The ModNotes context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.ModNotes.ModNote

  @doc """
  Returns the list of mod_notes.

  ## Examples

      iex> list_mod_notes()
      [%ModNote{}, ...]

  """
  def list_mod_notes do
    Repo.all(ModNote)
  end

  @doc """
  Gets a single mod_note.

  Raises `Ecto.NoResultsError` if the Mod note does not exist.

  ## Examples

      iex> get_mod_note!(123)
      %ModNote{}

      iex> get_mod_note!(456)
      ** (Ecto.NoResultsError)

  """
  def get_mod_note!(id), do: Repo.get!(ModNote, id)

  @doc """
  Creates a mod_note.

  ## Examples

      iex> create_mod_note(%{field: value})
      {:ok, %ModNote{}}

      iex> create_mod_note(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_mod_note(creator, attrs \\ %{}) do
    %ModNote{moderator_id: creator.id}
    |> ModNote.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a mod_note.

  ## Examples

      iex> update_mod_note(mod_note, %{field: new_value})
      {:ok, %ModNote{}}

      iex> update_mod_note(mod_note, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_mod_note(%ModNote{} = mod_note, attrs) do
    mod_note
    |> ModNote.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ModNote.

  ## Examples

      iex> delete_mod_note(mod_note)
      {:ok, %ModNote{}}

      iex> delete_mod_note(mod_note)
      {:error, %Ecto.Changeset{}}

  """
  def delete_mod_note(%ModNote{} = mod_note) do
    Repo.delete(mod_note)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking mod_note changes.

  ## Examples

      iex> change_mod_note(mod_note)
      %Ecto.Changeset{source: %ModNote{}}

  """
  def change_mod_note(%ModNote{} = mod_note) do
    ModNote.changeset(mod_note, %{})
  end
end
