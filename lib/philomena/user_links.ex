defmodule Philomena.UserLinks do
  @moduledoc """
  The UserLinks context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.UserLinks.UserLink
  alias Philomena.Badges.Badge
  alias Philomena.Badges.Award
  alias Philomena.Tags.Tag

  @doc """
  Returns the list of user_links.

  ## Examples

      iex> list_user_links()
      [%UserLink{}, ...]

  """
  def list_user_links do
    Repo.all(UserLink)
  end

  @doc """
  Gets a single user_link.

  Raises `Ecto.NoResultsError` if the User link does not exist.

  ## Examples

      iex> get_user_link!(123)
      %UserLink{}

      iex> get_user_link!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_link!(id), do: Repo.get!(UserLink, id)

  @doc """
  Creates a user_link.

  ## Examples

      iex> create_user_link(%{field: value})
      {:ok, %UserLink{}}

      iex> create_user_link(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_link(user, attrs \\ %{}) do
    tag = Repo.get_by(Tag, name: attrs["tag_name"])

    %UserLink{}
    |> UserLink.creation_changeset(attrs, user, tag)
    |> Repo.insert()
  end

  @doc """
  Updates a user_link.

  ## Examples

      iex> update_user_link(user_link, %{field: new_value})
      {:ok, %UserLink{}}

      iex> update_user_link(user_link, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_link(%UserLink{} = user_link, attrs) do
    tag = Repo.get_by(Tag, name: attrs["tag_name"])

    user_link
    |> UserLink.edit_changeset(attrs, tag)
    |> Repo.update()
  end

  def verify_user_link(%UserLink{} = user_link, user) do
    user_link_changeset =
      user_link
      |> UserLink.verify_changeset(user)

    Multi.new()
    |> Multi.update(:user_link, user_link_changeset)
    |> Multi.run(:add_award, fn repo, _changes ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      with badge when not is_nil(badge) <- repo.get_by(limit(Badge, 1), title: "Artist"),
           nil <- repo.get_by(limit(Award, 1), badge_id: badge.id, user_id: user_link.user_id) do
        %Award{
          badge_id: badge.id,
          user_id: user_link.user_id,
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

  def reject_user_link(%UserLink{} = user_link) do
    user_link
    |> UserLink.reject_changeset()
    |> Repo.update()
  end

  def contact_user_link(%UserLink{} = user_link, user) do
    user_link
    |> UserLink.contact_changeset(user)
    |> Repo.update()
  end

  @doc """
  Deletes a UserLink.

  ## Examples

      iex> delete_user_link(user_link)
      {:ok, %UserLink{}}

      iex> delete_user_link(user_link)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_link(%UserLink{} = user_link) do
    Repo.delete(user_link)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_link changes.

  ## Examples

      iex> change_user_link(user_link)
      %Ecto.Changeset{source: %UserLink{}}

  """
  def change_user_link(%UserLink{} = user_link) do
    UserLink.changeset(user_link, %{})
  end

  def count_user_links(user) do
    if Canada.Can.can?(user, :index, %UserLink{}) do
      UserLink
      |> where([ul], ul.aasm_state in ^["unverified", "link_verified", "contacted"])
      |> Repo.aggregate(:count, :id)
    else
      nil
    end
  end
end
