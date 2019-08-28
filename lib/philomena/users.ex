defmodule Philomena.Users do
  @moduledoc """
  The Users context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Users.User

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
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a User.

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
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{source: %User{}}

  """
  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  alias Philomena.Users.Ip

  @doc """
  Returns the list of user_ips.

  ## Examples

      iex> list_user_ips()
      [%Ip{}, ...]

  """
  def list_user_ips do
    Repo.all(Ip)
  end

  @doc """
  Gets a single ip.

  Raises `Ecto.NoResultsError` if the Ip does not exist.

  ## Examples

      iex> get_ip!(123)
      %Ip{}

      iex> get_ip!(456)
      ** (Ecto.NoResultsError)

  """
  def get_ip!(id), do: Repo.get!(Ip, id)

  @doc """
  Creates a ip.

  ## Examples

      iex> create_ip(%{field: value})
      {:ok, %Ip{}}

      iex> create_ip(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ip(attrs \\ %{}) do
    %Ip{}
    |> Ip.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a ip.

  ## Examples

      iex> update_ip(ip, %{field: new_value})
      {:ok, %Ip{}}

      iex> update_ip(ip, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ip(%Ip{} = ip, attrs) do
    ip
    |> Ip.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Ip.

  ## Examples

      iex> delete_ip(ip)
      {:ok, %Ip{}}

      iex> delete_ip(ip)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ip(%Ip{} = ip) do
    Repo.delete(ip)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ip changes.

  ## Examples

      iex> change_ip(ip)
      %Ecto.Changeset{source: %Ip{}}

  """
  def change_ip(%Ip{} = ip) do
    Ip.changeset(ip, %{})
  end

  alias Philomena.Users.Fingerprint

  @doc """
  Returns the list of user_fingerprints.

  ## Examples

      iex> list_user_fingerprints()
      [%Fingerprint{}, ...]

  """
  def list_user_fingerprints do
    Repo.all(Fingerprint)
  end

  @doc """
  Gets a single fingerprints.

  Raises `Ecto.NoResultsError` if the Fingerprint does not exist.

  ## Examples

      iex> get_fingerprints!(123)
      %Fingerprint{}

      iex> get_fingerprints!(456)
      ** (Ecto.NoResultsError)

  """
  def get_fingerprints!(id), do: Repo.get!(Fingerprint, id)

  @doc """
  Creates a fingerprints.

  ## Examples

      iex> create_fingerprints(%{field: value})
      {:ok, %Fingerprint{}}

      iex> create_fingerprints(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_fingerprints(attrs \\ %{}) do
    %Fingerprint{}
    |> Fingerprint.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a fingerprints.

  ## Examples

      iex> update_fingerprints(fingerprints, %{field: new_value})
      {:ok, %Fingerprint{}}

      iex> update_fingerprints(fingerprints, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_fingerprints(%Fingerprint{} = fingerprints, attrs) do
    fingerprints
    |> Fingerprint.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Fingerprint.

  ## Examples

      iex> delete_fingerprints(fingerprints)
      {:ok, %Fingerprint{}}

      iex> delete_fingerprints(fingerprints)
      {:error, %Ecto.Changeset{}}

  """
  def delete_fingerprints(%Fingerprint{} = fingerprints) do
    Repo.delete(fingerprints)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking fingerprints changes.

  ## Examples

      iex> change_fingerprints(fingerprints)
      %Ecto.Changeset{source: %Fingerprint{}}

  """
  def change_fingerprints(%Fingerprint{} = fingerprints) do
    Fingerprint.changeset(fingerprints, %{})
  end
end
