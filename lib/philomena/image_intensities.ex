defmodule Philomena.ImageIntensities do
  @moduledoc """
  The ImageIntensities context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.ImageIntensities.ImageIntensity

  @doc """
  Gets a single image_intensity.

  Raises `Ecto.NoResultsError` if the Image intensity does not exist.

  ## Examples

      iex> get_image_intensity!(123)
      %ImageIntensity{}

      iex> get_image_intensity!(456)
      ** (Ecto.NoResultsError)

  """
  def get_image_intensity!(id), do: Repo.get!(ImageIntensity, id)

  @doc """
  Creates a image_intensity.

  ## Examples

      iex> create_image_intensity(%{field: value})
      {:ok, %ImageIntensity{}}

      iex> create_image_intensity(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_image_intensity(image, attrs \\ %{}) do
    %ImageIntensity{image_id: image.id}
    |> ImageIntensity.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a image_intensity.

  ## Examples

      iex> update_image_intensity(image_intensity, %{field: new_value})
      {:ok, %ImageIntensity{}}

      iex> update_image_intensity(image_intensity, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_image_intensity(%ImageIntensity{} = image_intensity, attrs) do
    image_intensity
    |> ImageIntensity.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ImageIntensity.

  ## Examples

      iex> delete_image_intensity(image_intensity)
      {:ok, %ImageIntensity{}}

      iex> delete_image_intensity(image_intensity)
      {:error, %Ecto.Changeset{}}

  """
  def delete_image_intensity(%ImageIntensity{} = image_intensity) do
    Repo.delete(image_intensity)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking image_intensity changes.

  ## Examples

      iex> change_image_intensity(image_intensity)
      %Ecto.Changeset{source: %ImageIntensity{}}

  """
  def change_image_intensity(%ImageIntensity{} = image_intensity) do
    ImageIntensity.changeset(image_intensity, %{})
  end
end
