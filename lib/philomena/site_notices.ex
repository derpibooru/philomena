defmodule Philomena.SiteNotices do
  @moduledoc """
  The SiteNotices context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.SiteNotices.SiteNotice

  @doc """
  Returns the list of site_notices.

  ## Examples

      iex> list_site_notices()
      [%SiteNotice{}, ...]

  """
  def active_site_notices do
    now = DateTime.utc_now()

    SiteNotice
    |> where(live: true)
    |> where([n], n.start_date < ^now and n.finish_date > ^now)
    |> order_by(desc: :start_date)
    |> Repo.all()
  end

  @doc """
  Gets a single site_notice.

  Raises `Ecto.NoResultsError` if the Site notice does not exist.

  ## Examples

      iex> get_site_notice!(123)
      %SiteNotice{}

      iex> get_site_notice!(456)
      ** (Ecto.NoResultsError)

  """
  def get_site_notice!(id), do: Repo.get!(SiteNotice, id)

  @doc """
  Creates a site_notice.

  ## Examples

      iex> create_site_notice(%{field: value})
      {:ok, %SiteNotice{}}

      iex> create_site_notice(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_site_notice(creator, attrs \\ %{}) do
    %SiteNotice{user_id: creator.id}
    |> SiteNotice.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a site_notice.

  ## Examples

      iex> update_site_notice(site_notice, %{field: new_value})
      {:ok, %SiteNotice{}}

      iex> update_site_notice(site_notice, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_site_notice(%SiteNotice{} = site_notice, attrs) do
    site_notice
    |> SiteNotice.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a SiteNotice.

  ## Examples

      iex> delete_site_notice(site_notice)
      {:ok, %SiteNotice{}}

      iex> delete_site_notice(site_notice)
      {:error, %Ecto.Changeset{}}

  """
  def delete_site_notice(%SiteNotice{} = site_notice) do
    Repo.delete(site_notice)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking site_notice changes.

  ## Examples

      iex> change_site_notice(site_notice)
      %Ecto.Changeset{source: %SiteNotice{}}

  """
  def change_site_notice(%SiteNotice{} = site_notice) do
    SiteNotice.changeset(site_notice, %{})
  end
end
