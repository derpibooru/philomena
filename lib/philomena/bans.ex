defmodule Philomena.Bans do
  @moduledoc """
  The Bans context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Bans.Finder
  alias Philomena.Bans.Fingerprint
  alias Philomena.Bans.SubnetCreator
  alias Philomena.Bans.Subnet
  alias Philomena.Bans.User

  @doc """
  Returns the list of fingerprint bans.

  ## Examples

      iex> list_fingerprint_bans()
      [%Fingerprint{}, ...]

  """
  def list_fingerprint_bans do
    Repo.all(Fingerprint)
  end

  @doc """
  Gets a single fingerprint ban.

  Raises `Ecto.NoResultsError` if the fingerprint ban does not exist.

  ## Examples

      iex> get_fingerprint!(123)
      %Fingerprint{}

      iex> get_fingerprint!(456)
      ** (Ecto.NoResultsError)

  """
  def get_fingerprint!(id), do: Repo.get!(Fingerprint, id)

  @doc """
  Creates a fingerprint ban.

  ## Examples

      iex> create_fingerprint(%{field: value})
      {:ok, %Fingerprint{}}

      iex> create_fingerprint(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_fingerprint(creator, attrs \\ %{}) do
    %Fingerprint{banning_user_id: creator.id}
    |> Fingerprint.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a fingerprint ban.

  ## Examples

      iex> update_fingerprint(fingerprint, %{field: new_value})
      {:ok, %Fingerprint{}}

      iex> update_fingerprint(fingerprint, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_fingerprint(%Fingerprint{} = fingerprint, attrs) do
    fingerprint
    |> Fingerprint.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a fingerprint ban.

  ## Examples

      iex> delete_fingerprint(fingerprint)
      {:ok, %Fingerprint{}}

      iex> delete_fingerprint(fingerprint)
      {:error, %Ecto.Changeset{}}

  """
  def delete_fingerprint(%Fingerprint{} = fingerprint) do
    Repo.delete(fingerprint)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking fingerprint ban changes.

  ## Examples

      iex> change_fingerprint(fingerprint)
      %Ecto.Changeset{source: %Fingerprint{}}

  """
  def change_fingerprint(%Fingerprint{} = fingerprint) do
    Fingerprint.changeset(fingerprint, %{})
  end

  @doc """
  Returns the list of subnet bans.

  ## Examples

      iex> list_subnet_bans()
      [%Subnet{}, ...]

  """
  def list_subnet_bans do
    Repo.all(Subnet)
  end

  @doc """
  Gets a single subnet ban.

  Raises `Ecto.NoResultsError` if the subnet ban does not exist.

  ## Examples

      iex> get_subnet!(123)
      %Subnet{}

      iex> get_subnet!(456)
      ** (Ecto.NoResultsError)

  """
  def get_subnet!(id), do: Repo.get!(Subnet, id)

  @doc """
  Creates a subnet ban.

  ## Examples

      iex> create_subnet(%{field: value})
      {:ok, %Subnet{}}

      iex> create_subnet(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_subnet(creator, attrs \\ %{}) do
    %Subnet{banning_user_id: creator.id}
    |> Subnet.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a subnet ban.

  ## Examples

      iex> update_subnet(subnet, %{field: new_value})
      {:ok, %Subnet{}}

      iex> update_subnet(subnet, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_subnet(%Subnet{} = subnet, attrs) do
    subnet
    |> Subnet.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a subnet ban.

  ## Examples

      iex> delete_subnet(subnet)
      {:ok, %Subnet{}}

      iex> delete_subnet(subnet)
      {:error, %Ecto.Changeset{}}

  """
  def delete_subnet(%Subnet{} = subnet) do
    Repo.delete(subnet)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking subnet ban changes.

  ## Examples

      iex> change_subnet(subnet)
      %Ecto.Changeset{source: %Subnet{}}

  """
  def change_subnet(%Subnet{} = subnet) do
    Subnet.changeset(subnet, %{})
  end

  @doc """
  Returns the list of user bans.

  ## Examples

      iex> list_user_bans()
      [%User{}, ...]

  """
  def list_user_bans do
    Repo.all(User)
  end

  @doc """
  Gets a single user ban.

  Raises `Ecto.NoResultsError` if the user ban does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Creates a user ban.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(creator, attrs \\ %{}) do
    changeset =
      %User{banning_user_id: creator.id}
      |> User.changeset(attrs)

    Multi.new()
    |> Multi.insert(:user_ban, changeset)
    |> Multi.run(:subnet_ban, fn _repo, %{user_ban: %{user_id: user_id}} ->
      SubnetCreator.create_for_user(creator, user_id, attrs)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user_ban: user_ban}} ->
        {:ok, user_ban}

      {:error, :user_ban, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a user ban.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user ban.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user ban changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{source: %User{}}

  """
  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  @doc """
  Returns the first ban, if any, that matches the specified request attributes.
  """
  def find(user, ip, fingerprint) do
    Finder.find(user, ip, fingerprint)
  end
end
