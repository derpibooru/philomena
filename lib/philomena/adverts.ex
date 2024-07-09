defmodule Philomena.Adverts do
  @moduledoc """
  The Adverts context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Adverts.Advert
  alias Philomena.Adverts.Restrictions
  alias Philomena.Adverts.Server
  alias Philomena.Adverts.Uploader

  @doc """
  Gets an advert that is currently live.

  Returns the advert, or nil if nothing was live.

      iex> random_live()
      nil

      iex> random_live()
      %Advert{}

  """
  def random_live do
    random_live_for_tags([])
  end

  @doc """
  Gets an advert that is currently live, matching any tagging restrictions
  for the given image.

  Returns the advert, or nil if nothing was live.

  ## Examples

      iex> random_live(%Image{})
      nil

      iex> random_live(%Image{})
      %Advert{}

  """
  def random_live(image) do
    image
    |> Repo.preload(:tags)
    |> Map.get(:tags)
    |> Enum.map(& &1.name)
    |> random_live_for_tags()
  end

  defp random_live_for_tags(tags) do
    now = DateTime.utc_now()
    restrictions = Restrictions.tags(tags)

    query =
      from a in Advert,
        where: a.live == true,
        where: a.restrictions in ^restrictions,
        where: a.start_date < ^now and a.finish_date > ^now,
        order_by: [asc: fragment("random()")],
        limit: 1

    Repo.one(query)
  end

  @doc """
  Asynchronously records a new impression.

  ## Example

      iex> record_impression(%Advert{})
      :ok

  """
  def record_impression(%Advert{id: id}) do
    Server.record_impression(id)
  end

  @doc """
  Asynchronously records a new click.

  ## Example

      iex> record_click(%Advert{})
      :ok

  """
  def record_click(%Advert{id: id}) do
    Server.record_click(id)
  end

  @doc """
  Gets a single advert.

  Raises `Ecto.NoResultsError` if the Advert does not exist.

  ## Examples

      iex> get_advert!(123)
      %Advert{}

      iex> get_advert!(456)
      ** (Ecto.NoResultsError)

  """
  def get_advert!(id), do: Repo.get!(Advert, id)

  @doc """
  Creates an advert.

  ## Examples

      iex> create_advert(%{field: value})
      {:ok, %Advert{}}

      iex> create_advert(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_advert(attrs \\ %{}) do
    %Advert{}
    |> Advert.changeset(attrs)
    |> Uploader.analyze_upload(attrs)
    |> Repo.insert()
    |> case do
      {:ok, advert} ->
        Uploader.persist_upload(advert)
        Uploader.unpersist_old_upload(advert)

        {:ok, advert}

      error ->
        error
    end
  end

  @doc """
  Updates an Advert without updating its image.

  ## Examples

      iex> update_advert(advert, %{field: new_value})
      {:ok, %Advert{}}

      iex> update_advert(advert, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_advert(%Advert{} = advert, attrs) do
    advert
    |> Advert.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates the image for an Advert.

  ## Examples

      iex> update_advert_image(advert, %{image: new_value})
      {:ok, %Advert{}}

      iex> update_advert_image(advert, %{image: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_advert_image(%Advert{} = advert, attrs) do
    advert
    |> Advert.changeset(attrs)
    |> Uploader.analyze_upload(attrs)
    |> Repo.update()
    |> case do
      {:ok, advert} ->
        Uploader.persist_upload(advert)
        Uploader.unpersist_old_upload(advert)

        {:ok, advert}

      error ->
        error
    end
  end

  @doc """
  Deletes an Advert.

  ## Examples

      iex> delete_advert(advert)
      {:ok, %Advert{}}

      iex> delete_advert(advert)
      {:error, %Ecto.Changeset{}}

  """
  def delete_advert(%Advert{} = advert) do
    Repo.delete(advert)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking advert changes.

  ## Examples

      iex> change_advert(advert)
      %Ecto.Changeset{source: %Advert{}}

  """
  def change_advert(%Advert{} = advert) do
    Advert.changeset(advert, %{})
  end
end
