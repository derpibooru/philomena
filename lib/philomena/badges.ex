defmodule Philomena.Badges do
  @moduledoc """
  The Badges context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Badges.Badge
  alias Philomena.Badges.Uploader

  @doc """
  Returns the list of badges.

  ## Examples

      iex> list_badges()
      [%Badge{}, ...]

  """
  def list_badges do
    Repo.all(Badge)
  end

  @doc """
  Gets a single badge.

  Raises `Ecto.NoResultsError` if the Badge does not exist.

  ## Examples

      iex> get_badge!(123)
      %Badge{}

      iex> get_badge!(456)
      ** (Ecto.NoResultsError)

  """
  def get_badge!(id), do: Repo.get!(Badge, id)

  @doc """
  Gets a single badge by its title.

  Returns nil if the Badge does not exist.

  ## Examples

      iex> get_badge_by_title("Artist")
      %Badge{}

      iex> get_badge_by_title("Nonexistent")
      nil

  """
  def get_badge_by_title(title), do: Repo.get_by(Badge, title: title)

  @doc """
  Creates a badge.

  ## Examples

      iex> create_badge(%{field: value})
      {:ok, %Badge{}}

      iex> create_badge(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_badge(attrs \\ %{}) do
    %Badge{}
    |> Badge.changeset(attrs)
    |> Uploader.analyze_upload(attrs)
    |> Repo.insert()
    |> case do
      {:ok, badge} ->
        Uploader.persist_upload(badge)
        Uploader.unpersist_old_upload(badge)

        {:ok, badge}

      error ->
        error
    end
  end

  @doc """
  Updates a badge without updating its image.

  ## Examples

      iex> update_badge(badge, %{field: new_value})
      {:ok, %Badge{}}

      iex> update_badge(badge, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_badge(%Badge{} = badge, attrs) do
    badge
    |> Badge.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates the image for a badge.

  ## Examples

      iex> update_badge_image(badge, %{image: new_value})
      {:ok, %Badge{}}

      iex> update_badge_image(badge, %{image: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_badge_image(%Badge{} = badge, attrs) do
    badge
    |> Badge.changeset(attrs)
    |> Uploader.analyze_upload(attrs)
    |> Repo.update()
    |> case do
      {:ok, badge} ->
        Uploader.persist_upload(badge)
        Uploader.unpersist_old_upload(badge)

        {:ok, badge}

      error ->
        error
    end
  end

  @doc """
  Deletes a Badge.

  ## Examples

      iex> delete_badge(badge)
      {:ok, %Badge{}}

      iex> delete_badge(badge)
      {:error, %Ecto.Changeset{}}

  """
  def delete_badge(%Badge{} = badge) do
    Repo.delete(badge)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking badge changes.

  ## Examples

      iex> change_badge(badge)
      %Ecto.Changeset{source: %Badge{}}

  """
  def change_badge(%Badge{} = badge) do
    Badge.changeset(badge, %{})
  end

  alias Philomena.Badges.Award

  @doc """
  Returns the list of badge_awards.

  ## Examples

      iex> list_badge_awards()
      [%Award{}, ...]

  """
  def list_badge_awards do
    Repo.all(Award)
  end

  @doc """
  Gets a single badge_award.

  Raises `Ecto.NoResultsError` if the Badge award does not exist.

  ## Examples

      iex> get_badge_award!(123)
      %Award{}

      iex> get_badge_award!(456)
      ** (Ecto.NoResultsError)

  """
  def get_badge_award!(id), do: Repo.get!(Award, id)

  @doc """
  Gets a the badge_award with the given badge type belonging to the user.

  Raises nil if the Badge award does not exist.

  ## Examples

      iex> get_badge_award_for(badge, user)
      %Award{}

      iex> get_badge_award_for(badge, user)
      nil

  """
  def get_badge_award_for(badge, user) do
    Repo.get_by(Award, badge_id: badge.id, user_id: user.id)
  end

  @doc """
  Creates a badge_award.

  ## Examples

      iex> create_badge_award(%{field: value})
      {:ok, %Award{}}

      iex> create_badge_award(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_badge_award(creator, user, attrs \\ %{}) do
    %Award{awarded_by_id: creator.id, user_id: user.id}
    |> Award.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a badge_award.

  ## Examples

      iex> update_badge_award(badge_award, %{field: new_value})
      {:ok, %Award{}}

      iex> update_badge_award(badge_award, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_badge_award(%Award{} = badge_award, attrs) do
    badge_award
    |> Award.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Award.

  ## Examples

      iex> delete_badge_award(badge_award)
      {:ok, %Award{}}

      iex> delete_badge_award(badge_award)
      {:error, %Ecto.Changeset{}}

  """
  def delete_badge_award(%Award{} = badge_award) do
    Repo.delete(badge_award)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking badge_award changes.

  ## Examples

      iex> change_badge_award(badge_award)
      %Ecto.Changeset{source: %Award{}}

  """
  def change_badge_award(%Award{} = badge_award) do
    Award.changeset(badge_award, %{})
  end
end
