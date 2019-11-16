defmodule Philomena.ImageHides do
  @moduledoc """
  The ImageHides context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.ImageHides.ImageHide

  @doc """
  Returns the list of image_hides.

  ## Examples

      iex> list_image_hides()
      [%ImageHide{}, ...]

  """
  def list_image_hides do
    Repo.all(ImageHide)
  end

  @doc """
  Gets a single image_hide.

  Raises `Ecto.NoResultsError` if the Image hide does not exist.

  ## Examples

      iex> get_image_hide!(123)
      %ImageHide{}

      iex> get_image_hide!(456)
      ** (Ecto.NoResultsError)

  """
  def get_image_hide!(id), do: Repo.get!(ImageHide, id)

  @doc """
  Creates a image_hide.

  ## Examples

      iex> create_image_hide(%{field: value})
      {:ok, %ImageHide{}}

      iex> create_image_hide(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_image_hide(attrs \\ %{}) do
    %ImageHide{}
    |> ImageHide.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a image_hide.

  ## Examples

      iex> update_image_hide(image_hide, %{field: new_value})
      {:ok, %ImageHide{}}

      iex> update_image_hide(image_hide, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_image_hide(%ImageHide{} = image_hide, attrs) do
    image_hide
    |> ImageHide.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ImageHide.

  ## Examples

      iex> delete_image_hide(image_hide)
      {:ok, %ImageHide{}}

      iex> delete_image_hide(image_hide)
      {:error, %Ecto.Changeset{}}

  """
  def delete_image_hide(%ImageHide{} = image_hide) do
    Repo.delete(image_hide)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking image_hide changes.

  ## Examples

      iex> change_image_hide(image_hide)
      %Ecto.Changeset{source: %ImageHide{}}

  """
  def change_image_hide(%ImageHide{} = image_hide) do
    ImageHide.changeset(image_hide, %{})
  end
end
