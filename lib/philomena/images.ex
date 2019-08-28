defmodule Philomena.Images do
  @moduledoc """
  The Images context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Images.Image

  @doc """
  Returns the list of images.

  ## Examples

      iex> list_images()
      [%Image{}, ...]

  """
  def list_images do
    Repo.all(Image |> where(hidden_from_users: false) |> order_by(desc: :created_at) |> limit(25))
  end

  @doc """
  Gets a single image.

  Raises `Ecto.NoResultsError` if the Image does not exist.

  ## Examples

      iex> get_image!(123)
      %Image{}

      iex> get_image!(456)
      ** (Ecto.NoResultsError)

  """
  def get_image!(id) do
    Repo.one!(Image |> where(id: ^id) |> preload(:tags))
  end

  @doc """
  Creates a image.

  ## Examples

      iex> create_image(%{field: value})
      {:ok, %Image{}}

      iex> create_image(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_image(attrs \\ %{}) do
    %Image{}
    |> Image.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a image.

  ## Examples

      iex> update_image(image, %{field: new_value})
      {:ok, %Image{}}

      iex> update_image(image, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_image(%Image{} = image, attrs) do
    image
    |> Image.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Image.

  ## Examples

      iex> delete_image(image)
      {:ok, %Image{}}

      iex> delete_image(image)
      {:error, %Ecto.Changeset{}}

  """
  def delete_image(%Image{} = image) do
    Repo.delete(image)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking image changes.

  ## Examples

      iex> change_image(image)
      %Ecto.Changeset{source: %Image{}}

  """
  def change_image(%Image{} = image) do
    Image.changeset(image, %{})
  end

  alias Philomena.Images.Features

  @doc """
  Returns the list of image_features.

  ## Examples

      iex> list_image_features()
      [%Features{}, ...]

  """
  def list_image_features do
    Repo.all(Features)
  end

  @doc """
  Gets a single features.

  Raises `Ecto.NoResultsError` if the Features does not exist.

  ## Examples

      iex> get_features!(123)
      %Features{}

      iex> get_features!(456)
      ** (Ecto.NoResultsError)

  """
  def get_features!(id), do: Repo.get!(Features, id)

  @doc """
  Creates a features.

  ## Examples

      iex> create_features(%{field: value})
      {:ok, %Features{}}

      iex> create_features(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_features(attrs \\ %{}) do
    %Features{}
    |> Features.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a features.

  ## Examples

      iex> update_features(features, %{field: new_value})
      {:ok, %Features{}}

      iex> update_features(features, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_features(%Features{} = features, attrs) do
    features
    |> Features.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Features.

  ## Examples

      iex> delete_features(features)
      {:ok, %Features{}}

      iex> delete_features(features)
      {:error, %Ecto.Changeset{}}

  """
  def delete_features(%Features{} = features) do
    Repo.delete(features)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking features changes.

  ## Examples

      iex> change_features(features)
      %Ecto.Changeset{source: %Features{}}

  """
  def change_features(%Features{} = features) do
    Features.changeset(features, %{})
  end

  alias Philomena.Images.Intensities

  @doc """
  Returns the list of image_intensities.

  ## Examples

      iex> list_image_intensities()
      [%Intensities{}, ...]

  """
  def list_image_intensities do
    Repo.all(Intensities)
  end

  @doc """
  Gets a single intensities.

  Raises `Ecto.NoResultsError` if the Intensities does not exist.

  ## Examples

      iex> get_intensities!(123)
      %Intensities{}

      iex> get_intensities!(456)
      ** (Ecto.NoResultsError)

  """
  def get_intensities!(id), do: Repo.get!(Intensities, id)

  @doc """
  Creates a intensities.

  ## Examples

      iex> create_intensities(%{field: value})
      {:ok, %Intensities{}}

      iex> create_intensities(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_intensities(attrs \\ %{}) do
    %Intensities{}
    |> Intensities.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a intensities.

  ## Examples

      iex> update_intensities(intensities, %{field: new_value})
      {:ok, %Intensities{}}

      iex> update_intensities(intensities, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_intensities(%Intensities{} = intensities, attrs) do
    intensities
    |> Intensities.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Intensities.

  ## Examples

      iex> delete_intensities(intensities)
      {:ok, %Intensities{}}

      iex> delete_intensities(intensities)
      {:error, %Ecto.Changeset{}}

  """
  def delete_intensities(%Intensities{} = intensities) do
    Repo.delete(intensities)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking intensities changes.

  ## Examples

      iex> change_intensities(intensities)
      %Ecto.Changeset{source: %Intensities{}}

  """
  def change_intensities(%Intensities{} = intensities) do
    Intensities.changeset(intensities, %{})
  end

  alias Philomena.Images.Subscription

  @doc """
  Returns the list of image_subscriptions.

  ## Examples

      iex> list_image_subscriptions()
      [%Subscription{}, ...]

  """
  def list_image_subscriptions do
    Repo.all(Subscription)
  end

  @doc """
  Gets a single subscription.

  Raises `Ecto.NoResultsError` if the Subscription does not exist.

  ## Examples

      iex> get_subscription!(123)
      %Subscription{}

      iex> get_subscription!(456)
      ** (Ecto.NoResultsError)

  """
  def get_subscription!(id), do: Repo.get!(Subscription, id)

  @doc """
  Creates a subscription.

  ## Examples

      iex> create_subscription(%{field: value})
      {:ok, %Subscription{}}

      iex> create_subscription(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_subscription(attrs \\ %{}) do
    %Subscription{}
    |> Subscription.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a subscription.

  ## Examples

      iex> update_subscription(subscription, %{field: new_value})
      {:ok, %Subscription{}}

      iex> update_subscription(subscription, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_subscription(%Subscription{} = subscription, attrs) do
    subscription
    |> Subscription.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Subscription.

  ## Examples

      iex> delete_subscription(subscription)
      {:ok, %Subscription{}}

      iex> delete_subscription(subscription)
      {:error, %Ecto.Changeset{}}

  """
  def delete_subscription(%Subscription{} = subscription) do
    Repo.delete(subscription)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking subscription changes.

  ## Examples

      iex> change_subscription(subscription)
      %Ecto.Changeset{source: %Subscription{}}

  """
  def change_subscription(%Subscription{} = subscription) do
    Subscription.changeset(subscription, %{})
  end
end
