defmodule Philomena.ModNotes do
  @moduledoc """
  The ModNotes context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.ModNotes.ModNote
  alias Philomena.Polymorphic

  @doc """
  Returns a list of 2-tuples of mod notes and rendered output for the notable type and id.

  See `list_mod_notes/3` for more information about collection rendering.

  ## Examples

      iex> list_all_mod_notes_by_type_and_id("User", "1", & &1.body)
      [
        {%ModNote{body: "hello *world*"}, "hello *world*"}
      ]

  """
  def list_all_mod_notes_by_type_and_id(notable_type, notable_id, collection_renderer) do
    ModNote
    |> where(notable_type: ^notable_type, notable_id: ^notable_id)
    |> preload(:moderator)
    |> order_by(desc: :id)
    |> Repo.all()
    |> preload_and_render(collection_renderer)
  end

  @doc """
  Returns a `m:Scrivener.Page` of 2-tuples of mod notes and rendered output
  for the query string and current pagination.

  All mod notes containing the substring `query_string` are matched and returned
  case-insensitively.

  See `list_mod_notes/3` for more information.

  ## Examples

      iex> list_mod_notes_by_query_string("quack", & &1.body, page_size: 15)
      %Scrivener.Page{}

  """
  def list_mod_notes_by_query_string(query_string, collection_renderer, pagination) do
    ModNote
    |> where([m], ilike(m.body, ^"%#{query_string}%"))
    |> list_mod_notes(collection_renderer, pagination)
  end

  @doc """
  Returns a `m:Scrivener.Page` of 2-tuples of mod notes and rendered output
  for the current pagination.

  When coerced to a list and rendered as Markdown, the result may look like:

      [
        {%ModNote{body: "hello *world*"}, "hello <em>world</em>"}
      ]

  ## Examples

      iex> list_mod_notes(& &1.body, page_size: 15)
      %Scrivener.Page{}

  """
  def list_mod_notes(queryable \\ ModNote, collection_renderer, pagination) do
    mod_notes =
      queryable
      |> preload(:moderator)
      |> order_by(desc: :id)
      |> Repo.paginate(pagination)

    put_in(mod_notes.entries, preload_and_render(mod_notes, collection_renderer))
  end

  defp preload_and_render(mod_notes, collection_renderer) do
    bodies = collection_renderer.(mod_notes)
    preloaded = Polymorphic.load_polymorphic(mod_notes, notable: [notable_id: :notable_type])

    Enum.zip(preloaded, bodies)
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
