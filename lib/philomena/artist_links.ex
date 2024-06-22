defmodule Philomena.ArtistLinks do
  @moduledoc """
  The ArtistLinks context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.ArtistLinks.AutomaticVerifier
  alias Philomena.ArtistLinks.BadgeAwarder
  alias Philomena.Tags.Tag

  @doc """
  Updates all links pending verification to transition to link verified or reset
  next update time.
  """
  def automatic_verify! do
    Enum.each(AutomaticVerifier.generate_updates(), &Repo.update!/1)
  end

  @doc """
  Gets a single artist_link.

  Raises `Ecto.NoResultsError` if the Artist link does not exist.

  ## Examples

      iex> get_artist_link!(123)
      %ArtistLink{}

      iex> get_artist_link!(456)
      ** (Ecto.NoResultsError)

  """
  def get_artist_link!(id), do: Repo.get!(ArtistLink, id)

  @doc """
  Creates a artist_link.

  ## Examples

      iex> create_artist_link(%{field: value})
      {:ok, %ArtistLink{}}

      iex> create_artist_link(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_artist_link(user, attrs \\ %{}) do
    tag = fetch_tag(attrs["tag_name"])

    %ArtistLink{}
    |> ArtistLink.creation_changeset(attrs, user, tag)
    |> Repo.insert()
  end

  @doc """
  Updates a artist_link.

  ## Examples

      iex> update_artist_link(artist_link, %{field: new_value})
      {:ok, %ArtistLink{}}

      iex> update_artist_link(artist_link, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_artist_link(%ArtistLink{} = artist_link, attrs) do
    tag = fetch_tag(attrs["tag_name"])

    artist_link
    |> ArtistLink.edit_changeset(attrs, tag)
    |> Repo.update()
  end

  @doc """
  Transitions an artist_link to the verified state.

  ## Examples

      iex> verify_artist_link(artist_link, verifying_user)
      {:ok, %ArtistLink{}}

      iex> verify_artist_link(artist_link, verifying_user)
      :error

  """
  def verify_artist_link(%ArtistLink{} = artist_link, verifying_user) do
    artist_link_changeset = ArtistLink.verify_changeset(artist_link, verifying_user)

    Multi.new()
    |> Multi.update(:artist_link, artist_link_changeset)
    |> Multi.run(:add_award, fn _repo, _changes -> BadgeAwarder.award_badge(artist_link) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{artist_link: artist_link}} ->
        {:ok, artist_link}

      {:error, _operation, _value, _changes} ->
        :error
    end
  end

  def reject_artist_link(%ArtistLink{} = artist_link) do
    artist_link
    |> ArtistLink.reject_changeset()
    |> Repo.update()
  end

  def contact_artist_link(%ArtistLink{} = artist_link, user) do
    artist_link
    |> ArtistLink.contact_changeset(user)
    |> Repo.update()
  end

  @doc """
  Deletes a ArtistLink.

  ## Examples

      iex> delete_artist_link(artist_link)
      {:ok, %ArtistLink{}}

      iex> delete_artist_link(artist_link)
      {:error, %Ecto.Changeset{}}

  """
  def delete_artist_link(%ArtistLink{} = artist_link) do
    Repo.delete(artist_link)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking artist_link changes.

  ## Examples

      iex> change_artist_link(artist_link)
      %Ecto.Changeset{source: %ArtistLink{}}

  """
  def change_artist_link(%ArtistLink{} = artist_link) do
    ArtistLink.changeset(artist_link, %{})
  end

  def count_artist_links(user) do
    if Canada.Can.can?(user, :index, %ArtistLink{}) do
      ArtistLink
      |> where([ul], ul.aasm_state in ^["unverified", "link_verified"])
      |> Repo.aggregate(:count, :id)
    else
      nil
    end
  end

  defp fetch_tag(name) do
    Tag
    |> preload(:aliased_tag)
    |> where(name: ^name)
    |> Repo.one()
    |> case do
      nil -> nil
      tag -> tag.aliased_tag || tag
    end
  end
end
