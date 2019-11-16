defmodule Philomena.ImageFeatures do
  @moduledoc """
  The ImageFeatures context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.ImageFeatures.ImageFeature

  @doc """
  Returns the list of image_features.

  ## Examples

      iex> list_image_features()
      [%ImageFeature{}, ...]

  """
  def list_image_features do
    Repo.all(ImageFeature)
  end

  @doc """
  Gets a single image_feature.

  Raises `Ecto.NoResultsError` if the Image feature does not exist.

  ## Examples

      iex> get_image_feature!(123)
      %ImageFeature{}

      iex> get_image_feature!(456)
      ** (Ecto.NoResultsError)

  """
  def get_image_feature!(id), do: Repo.get!(ImageFeature, id)

  @doc """
  Creates a image_feature.

  ## Examples

      iex> create_image_feature(%{field: value})
      {:ok, %ImageFeature{}}

      iex> create_image_feature(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_image_feature(attrs \\ %{}) do
    %ImageFeature{}
    |> ImageFeature.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a image_feature.

  ## Examples

      iex> update_image_feature(image_feature, %{field: new_value})
      {:ok, %ImageFeature{}}

      iex> update_image_feature(image_feature, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_image_feature(%ImageFeature{} = image_feature, attrs) do
    image_feature
    |> ImageFeature.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ImageFeature.

  ## Examples

      iex> delete_image_feature(image_feature)
      {:ok, %ImageFeature{}}

      iex> delete_image_feature(image_feature)
      {:error, %Ecto.Changeset{}}

  """
  def delete_image_feature(%ImageFeature{} = image_feature) do
    Repo.delete(image_feature)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking image_feature changes.

  ## Examples

      iex> change_image_feature(image_feature)
      %Ecto.Changeset{source: %ImageFeature{}}

  """
  def change_image_feature(%ImageFeature{} = image_feature) do
    ImageFeature.changeset(image_feature, %{})
  end
end
