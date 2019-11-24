defmodule Philomena.Tags do
  @moduledoc """
  The Tags context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Tags.Tag

  @spec get_or_create_tags(String.t()) :: List.t()
  def get_or_create_tags(tag_list) do
    tag_names = Tag.parse_tag_list(tag_list)

    existent_tags =
      Tag
      |> where([t], t.name in ^tag_names)
      |> preload(:implied_tags)
      |> Repo.all()

    existent_tag_names =
      existent_tags
      |> Map.new(&{&1.name, true})

    nonexistent_tag_names =
      tag_names
      |> Enum.reject(&existent_tag_names[&1])

    new_tags =
      nonexistent_tag_names
      |> Enum.map(fn name ->
        {:ok, tag} =
          %Tag{}
          |> Tag.creation_changeset(%{name: name})
          |> Repo.insert()

        %{tag | implied_tags: []}
      end)

    new_tags
    |> reindex_tags()

    existent_tags ++ new_tags
  end

  @doc """
  Gets a single tag.

  Raises `Ecto.NoResultsError` if the Tag does not exist.

  ## Examples

      iex> get_tag!(123)
      %Tag{}

      iex> get_tag!(456)
      ** (Ecto.NoResultsError)

  """
  def get_tag!(slug), do: Repo.get_by!(Tag, slug: slug)

  @doc """
  Creates a tag.

  ## Examples

      iex> create_tag(%{field: value})
      {:ok, %Tag{}}

      iex> create_tag(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_tag(attrs \\ %{}) do
    %Tag{}
    |> Tag.creation_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tag.

  ## Examples

      iex> update_tag(tag, %{field: new_value})
      {:ok, %Tag{}}

      iex> update_tag(tag, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_tag(%Tag{} = tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Tag.

  ## Examples

      iex> delete_tag(tag)
      {:ok, %Tag{}}

      iex> delete_tag(tag)
      {:error, %Ecto.Changeset{}}

  """
  def delete_tag(%Tag{} = tag) do
    Repo.delete(tag)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tag changes.

  ## Examples

      iex> change_tag(tag)
      %Ecto.Changeset{source: %Tag{}}

  """
  def change_tag(%Tag{} = tag) do
    Tag.changeset(tag, %{})
  end

  def reindex_tag(%Tag{} = tag) do
    reindex_tags([%Tag{id: tag.id}])
  end

  def reindex_tags(tags) do
    spawn fn ->
      ids =
        tags
        |> Enum.map(& &1.id)

      Tag
      |> preload(^indexing_preloads())
      |> where([t], t.id in ^ids)
      |> Tag.reindex()
    end

    tags
  end

  def indexing_preloads do
    [:aliased_tag, :aliases, :implied_tags, :implied_by_tags]
  end

  alias Philomena.Tags.Implication

  @doc """
  Returns the list of tags_implied_tags.

  ## Examples

      iex> list_tags_implied_tags()
      [%Implication{}, ...]

  """
  def list_tags_implied_tags do
    Repo.all(Implication)
  end

  @doc """
  Gets a single implication.

  Raises `Ecto.NoResultsError` if the Implication does not exist.

  ## Examples

      iex> get_implication!(123)
      %Implication{}

      iex> get_implication!(456)
      ** (Ecto.NoResultsError)

  """
  def get_implication!(id), do: Repo.get!(Implication, id)

  @doc """
  Creates a implication.

  ## Examples

      iex> create_implication(%{field: value})
      {:ok, %Implication{}}

      iex> create_implication(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_implication(attrs \\ %{}) do
    %Implication{}
    |> Implication.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a implication.

  ## Examples

      iex> update_implication(implication, %{field: new_value})
      {:ok, %Implication{}}

      iex> update_implication(implication, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_implication(%Implication{} = implication, attrs) do
    implication
    |> Implication.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Implication.

  ## Examples

      iex> delete_implication(implication)
      {:ok, %Implication{}}

      iex> delete_implication(implication)
      {:error, %Ecto.Changeset{}}

  """
  def delete_implication(%Implication{} = implication) do
    Repo.delete(implication)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking implication changes.

  ## Examples

      iex> change_implication(implication)
      %Ecto.Changeset{source: %Implication{}}

  """
  def change_implication(%Implication{} = implication) do
    Implication.changeset(implication, %{})
  end
end
