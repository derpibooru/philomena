defmodule Philomena.ArtistLinks do
  @moduledoc """
  The ArtistLinks context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.ArtistLinks.AutomaticVerifier
  alias Philomena.Badges.Badge
  alias Philomena.Badges.Award
  alias Philomena.Tags.Tag

  @doc """
  Check links pending verification to see if the user placed
  the appropriate code on the page.
  """
  def automatic_verify! do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Automatically retry in an hour if we don't manage to
    # successfully verify any given link
    recheck_time = DateTime.add(now, 3600, :second)

    recheck_query =
      from ul in ArtistLink,
        where: ul.aasm_state == "unverified",
        where: ul.next_check_at < ^now

    recheck_query
    |> Repo.all()
    |> Enum.map(fn link ->
      ArtistLink.automatic_verify_changeset(
        link,
        AutomaticVerifier.check_link(link, recheck_time)
      )
    end)
    |> Enum.map(&Repo.update!/1)
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

  def verify_artist_link(%ArtistLink{} = artist_link, user) do
    artist_link_changeset =
      artist_link
      |> ArtistLink.verify_changeset(user)

    Multi.new()
    |> Multi.update(:artist_link, artist_link_changeset)
    |> Multi.run(:add_award, fn repo, _changes ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      with badge when not is_nil(badge) <- repo.get_by(limit(Badge, 1), title: "Artist"),
           nil <- repo.get_by(limit(Award, 1), badge_id: badge.id, user_id: artist_link.user_id) do
        %Award{
          badge_id: badge.id,
          user_id: artist_link.user_id,
          awarded_by_id: user.id,
          awarded_on: now
        }
        |> Award.changeset(%{})
        |> repo.insert()
      else
        _ ->
          {:ok, nil}
      end
    end)
    |> Repo.transaction()
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
      |> where([ul], ul.aasm_state in ^["unverified", "link_verified", "contacted"])
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
