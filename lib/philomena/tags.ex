defmodule Philomena.Tags do
  @moduledoc """
  The Tags context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Tags.Tag

  @doc """
  Returns the list of tags.

  ## Examples

      iex> list_tags()
      [%Tag{}, ...]

  """
  def list_tags do
    Repo.all(Tag |> order_by(desc: :images_count) |> limit(250))
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
    |> Tag.changeset(attrs)
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
