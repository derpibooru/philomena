defmodule Philomena.Users do
  @moduledoc """
  The Users context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Users.Uploader
  alias Philomena.Users.User
  alias Philomena.Roles.Role

  use Pow.Ecto.Context,
    repo: Repo,
    user: User

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    roles = 
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    roles =
      Role
      |> where([r], r.id in ^clean_roles(attrs["roles"]))
      |> Repo.all()

    user
    |> User.update_changeset(attrs, roles)
    |> Repo.update()
  end

  defp clean_roles(nil), do: []
  defp clean_roles(roles), do: Enum.filter(roles, &"" != &1)

  def update_spoiler_type(%User{} = user, attrs) do
    user
    |> User.spoiler_type_changeset(attrs)
    |> Repo.update()
  end

  def update_settings(%User{} = user, attrs) do
    user
    |> User.settings_changeset(attrs)
    |> Repo.update()
  end

  def update_description(%User{} = user, attrs) do
    user
    |> User.description_changeset(attrs)
    |> Repo.update()
  end

  def watch_tag(%User{} = user, tag) do
    watched_tag_ids = Enum.uniq([tag.id | user.watched_tag_ids])

    user
    |> User.watched_tags_changeset(watched_tag_ids)
    |> Repo.update()
  end

  def unwatch_tag(%User{} = user, tag) do
    watched_tag_ids = user.watched_tag_ids -- [tag.id]

    user
    |> User.watched_tags_changeset(watched_tag_ids)
    |> Repo.update()
  end

  def update_avatar(%User{} = user, attrs) do
    changeset = Uploader.analyze_upload(user, attrs)

    Multi.new
    |> Multi.update(:user, changeset)
    |> Multi.run(:update_file, fn _repo, %{user: user} ->
      Uploader.persist_upload(user)
      Uploader.unpersist_old_upload(user)

      {:ok, nil}
    end)
    |> Repo.isolated_transaction(:serializable)
  end

  def remove_avatar(%User{} = user) do
    changeset = User.remove_avatar_changeset(user)

    Multi.new
    |> Multi.update(:user, changeset)
    |> Multi.run(:remove_file, fn _repo, %{user: user} ->
      Uploader.unpersist_old_upload(user)

      {:ok, nil}
    end)
    |> Repo.isolated_transaction(:serializable)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{source: %User{}}

  """
  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  @impl Pow.Ecto.Context
  def delete(user) do
    {:error, User.changeset(user, %{})}
  end

  @impl Pow.Ecto.Context
  def create(params) do
    %User{}
    |> User.creation_changeset(params)
    |> Repo.insert()
  end

  @impl Pow.Ecto.Context
  def get_by(clauses) do
    User
    |> join(:left, [u], _ in assoc(u, :roles))
    |> join(:left, [u, _], _ in assoc(u, :current_filter))
    |> preload([_, r, cf], [current_filter: cf, roles: r])
    |> Repo.get_by(clauses)
    |> setup_roles()
  end

  defp setup_roles(nil), do: nil
  defp setup_roles(user) do
    role_map = Map.new(user.roles, &{&1.resource_type || &1.name, &1.name})

    %{user | role_map: role_map}
  end
end
