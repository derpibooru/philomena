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
  alias Philomena.Tags

  @doc """
  Updates all artist links pending verification, by transitioning to link verified state
  or resetting next update time.
  """
  def automatic_verify! do
    Enum.each(AutomaticVerifier.generate_updates(), &Repo.update!/1)
  end

  @doc """
  Gets a single artist link.

  Raises `Ecto.NoResultsError` if the Artist link does not exist.

  ## Examples

      iex> get_artist_link!(123)
      %ArtistLink{}

      iex> get_artist_link!(456)
      ** (Ecto.NoResultsError)

  """
  def get_artist_link!(id), do: Repo.get!(ArtistLink, id)

  @doc """
  Creates an artist link.

  ## Examples

      iex> create_artist_link(%{field: value})
      {:ok, %ArtistLink{}}

      iex> create_artist_link(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_artist_link(user, attrs \\ %{}) do
    tag = Tags.get_tag_or_alias_by_name(attrs["tag_name"])

    %ArtistLink{}
    |> ArtistLink.creation_changeset(attrs, user, tag)
    |> Repo.insert()
  end

  @doc """
  Updates an artist link.

  ## Examples

      iex> update_artist_link(artist_link, %{field: new_value})
      {:ok, %ArtistLink{}}

      iex> update_artist_link(artist_link, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_artist_link(%ArtistLink{} = artist_link, attrs) do
    tag = Tags.get_tag_or_alias_by_name(attrs["tag_name"])

    artist_link
    |> ArtistLink.edit_changeset(attrs, tag)
    |> Repo.update()
  end

  @doc """
  Transitions an artist link to the verified state.

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
    |> Multi.run(
      :add_award,
      BadgeAwarder.award_callback(artist_link.user, verifying_user, "Artist")
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{artist_link: artist_link}} ->
        {:ok, artist_link}

      {:error, _operation, _value, _changes} ->
        :error
    end
  end

  @doc """
  Transitions an artist link to the rejected state.

  ## Examples

      iex> reject_artist_link(artist_link)
      {:ok, %ArtistLink{}}

      iex> reject_artist_link(artist_link)
      {:error, %Ecto.Changeset{}}

  """
  def reject_artist_link(%ArtistLink{} = artist_link) do
    artist_link
    |> ArtistLink.reject_changeset()
    |> Repo.update()
  end

  @doc """
  Transitions an artist link to the contacted state.

  ## Examples

      iex> contact_artist_link(artist_link)
      {:ok, %ArtistLink{}}

      iex> contact_artist_link(artist_link)
      {:error, %Ecto.Changeset{}}

  """
  def contact_artist_link(%ArtistLink{} = artist_link, user) do
    artist_link
    |> ArtistLink.contact_changeset(user)
    |> Repo.update()
  end

  @doc """
  Deletes an artist link.

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
  Returns an `%Ecto.Changeset{}` for tracking artist link changes.

  ## Examples

      iex> change_artist_link(artist_link)
      %Ecto.Changeset{source: %ArtistLink{}}

  """
  def change_artist_link(%ArtistLink{} = artist_link) do
    ArtistLink.changeset(artist_link, %{})
  end

  @doc """
  Counts the number of artist links which are pending moderation action, or
  nil if the user is not permitted to moderate artist links.

  ## Examples

      iex> count_artist_links(normal_user)
      nil

      iex> count_artist_links(admin_user)
      0

  """
  def count_artist_links(user) do
    if Canada.Can.can?(user, :index, %ArtistLink{}) do
      ArtistLink
      |> where([ul], ul.aasm_state in ^["unverified", "link_verified"])
      |> Repo.aggregate(:count)
    else
      nil
    end
  end
end
