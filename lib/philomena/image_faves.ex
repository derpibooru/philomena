defmodule Philomena.ImageFaves do
  @moduledoc """
  The ImageFaves context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.ImageFaves.ImageFave

  @doc """
  Returns the list of image_faves.

  ## Examples

      iex> list_image_faves()
      [%ImageFave{}, ...]

  """
  def list_image_faves do
    Repo.all(ImageFave)
  end

  @doc """
  Gets a single image_fave.

  Raises `Ecto.NoResultsError` if the Image fave does not exist.

  ## Examples

      iex> get_image_fave!(123)
      %ImageFave{}

      iex> get_image_fave!(456)
      ** (Ecto.NoResultsError)

  """
  def get_image_fave!(id), do: Repo.get!(ImageFave, id)

  @doc """
  Creates a image_fave.

  ## Examples

      iex> create_image_fave(%{field: value})
      {:ok, %ImageFave{}}

      iex> create_image_fave(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_image_fave(attrs \\ %{}) do
    %ImageFave{}
    |> ImageFave.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a image_fave.

  ## Examples

      iex> update_image_fave(image_fave, %{field: new_value})
      {:ok, %ImageFave{}}

      iex> update_image_fave(image_fave, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_image_fave(%ImageFave{} = image_fave, attrs) do
    image_fave
    |> ImageFave.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ImageFave.

  ## Examples

      iex> delete_image_fave(image_fave)
      {:ok, %ImageFave{}}

      iex> delete_image_fave(image_fave)
      {:error, %Ecto.Changeset{}}

  """
  def delete_image_fave(%ImageFave{} = image_fave) do
    Repo.delete(image_fave)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking image_fave changes.

  ## Examples

      iex> change_image_fave(image_fave)
      %Ecto.Changeset{source: %ImageFave{}}

  """
  def change_image_fave(%ImageFave{} = image_fave) do
    ImageFave.changeset(image_fave, %{})
  end
end
