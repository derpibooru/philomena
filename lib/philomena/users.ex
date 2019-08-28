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

  alias Philomena.Users.Link

  @doc """
  Returns the list of user_links.

  ## Examples

      iex> list_user_links()
      [%Link{}, ...]

  """
  def list_user_links do
    Repo.all(Link)
  end

  @doc """
  Gets a single link.

  Raises `Ecto.NoResultsError` if the Link does not exist.

  ## Examples

      iex> get_link!(123)
      %Link{}

      iex> get_link!(456)
      ** (Ecto.NoResultsError)

  """
  def get_link!(id), do: Repo.get!(Link, id)

  @doc """
  Creates a link.

  ## Examples

      iex> create_link(%{field: value})
      {:ok, %Link{}}

      iex> create_link(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_link(attrs \\ %{}) do
    %Link{}
    |> Link.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a link.

  ## Examples

      iex> update_link(link, %{field: new_value})
      {:ok, %Link{}}

      iex> update_link(link, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_link(%Link{} = link, attrs) do
    link
    |> Link.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Link.

  ## Examples

      iex> delete_link(link)
      {:ok, %Link{}}

      iex> delete_link(link)
      {:error, %Ecto.Changeset{}}

  """
  def delete_link(%Link{} = link) do
    Repo.delete(link)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking link changes.

  ## Examples

      iex> change_link(link)
      %Ecto.Changeset{source: %Link{}}

  """
  def change_link(%Link{} = link) do
    Link.changeset(link, %{})
  end

  alias Philomena.Users.NameChange

  @doc """
  Returns the list of user_name_changes.

  ## Examples

      iex> list_user_name_changes()
      [%NameChange{}, ...]

  """
  def list_user_name_changes do
    Repo.all(NameChange)
  end

  @doc """
  Gets a single name_change.

  Raises `Ecto.NoResultsError` if the Name change does not exist.

  ## Examples

      iex> get_name_change!(123)
      %NameChange{}

      iex> get_name_change!(456)
      ** (Ecto.NoResultsError)

  """
  def get_name_change!(id), do: Repo.get!(NameChange, id)

  @doc """
  Creates a name_change.

  ## Examples

      iex> create_name_change(%{field: value})
      {:ok, %NameChange{}}

      iex> create_name_change(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_name_change(attrs \\ %{}) do
    %NameChange{}
    |> NameChange.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a name_change.

  ## Examples

      iex> update_name_change(name_change, %{field: new_value})
      {:ok, %NameChange{}}

      iex> update_name_change(name_change, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_name_change(%NameChange{} = name_change, attrs) do
    name_change
    |> NameChange.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a NameChange.

  ## Examples

      iex> delete_name_change(name_change)
      {:ok, %NameChange{}}

      iex> delete_name_change(name_change)
      {:error, %Ecto.Changeset{}}

  """
  def delete_name_change(%NameChange{} = name_change) do
    Repo.delete(name_change)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking name_change changes.

  ## Examples

      iex> change_name_change(name_change)
      %Ecto.Changeset{source: %NameChange{}}

  """
  def change_name_change(%NameChange{} = name_change) do
    NameChange.changeset(name_change, %{})
  end

  alias Philomena.Users.Statistic

  @doc """
  Returns the list of user_statistics.

  ## Examples

      iex> list_user_statistics()
      [%Statistic{}, ...]

  """
  def list_user_statistics do
    Repo.all(Statistic)
  end

  @doc """
  Gets a single statistic.

  Raises `Ecto.NoResultsError` if the Statistic does not exist.

  ## Examples

      iex> get_statistic!(123)
      %Statistic{}

      iex> get_statistic!(456)
      ** (Ecto.NoResultsError)

  """
  def get_statistic!(id), do: Repo.get!(Statistic, id)

  @doc """
  Creates a statistic.

  ## Examples

      iex> create_statistic(%{field: value})
      {:ok, %Statistic{}}

      iex> create_statistic(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_statistic(attrs \\ %{}) do
    %Statistic{}
    |> Statistic.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a statistic.

  ## Examples

      iex> update_statistic(statistic, %{field: new_value})
      {:ok, %Statistic{}}

      iex> update_statistic(statistic, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_statistic(%Statistic{} = statistic, attrs) do
    statistic
    |> Statistic.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Statistic.

  ## Examples

      iex> delete_statistic(statistic)
      {:ok, %Statistic{}}

      iex> delete_statistic(statistic)
      {:error, %Ecto.Changeset{}}

  """
  def delete_statistic(%Statistic{} = statistic) do
    Repo.delete(statistic)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking statistic changes.

  ## Examples

      iex> change_statistic(statistic)
      %Ecto.Changeset{source: %Statistic{}}

  """
  def change_statistic(%Statistic{} = statistic) do
    Statistic.changeset(statistic, %{})
  end

  alias Philomena.Users.Whitelist

  @doc """
  Returns the list of user_whitelists.

  ## Examples

      iex> list_user_whitelists()
      [%Whitelist{}, ...]

  """
  def list_user_whitelists do
    Repo.all(Whitelist)
  end

  @doc """
  Gets a single whitelist.

  Raises `Ecto.NoResultsError` if the Whitelist does not exist.

  ## Examples

      iex> get_whitelist!(123)
      %Whitelist{}

      iex> get_whitelist!(456)
      ** (Ecto.NoResultsError)

  """
  def get_whitelist!(id), do: Repo.get!(Whitelist, id)

  @doc """
  Creates a whitelist.

  ## Examples

      iex> create_whitelist(%{field: value})
      {:ok, %Whitelist{}}

      iex> create_whitelist(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_whitelist(attrs \\ %{}) do
    %Whitelist{}
    |> Whitelist.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a whitelist.

  ## Examples

      iex> update_whitelist(whitelist, %{field: new_value})
      {:ok, %Whitelist{}}

      iex> update_whitelist(whitelist, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_whitelist(%Whitelist{} = whitelist, attrs) do
    whitelist
    |> Whitelist.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Whitelist.

  ## Examples

      iex> delete_whitelist(whitelist)
      {:ok, %Whitelist{}}

      iex> delete_whitelist(whitelist)
      {:error, %Ecto.Changeset{}}

  """
  def delete_whitelist(%Whitelist{} = whitelist) do
    Repo.delete(whitelist)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking whitelist changes.

  ## Examples

      iex> change_whitelist(whitelist)
      %Ecto.Changeset{source: %Whitelist{}}

  """
  def change_whitelist(%Whitelist{} = whitelist) do
    Whitelist.changeset(whitelist, %{})
  end

  alias Philomena.Users.Role

  @doc """
  Returns the list of users_roles.

  ## Examples

      iex> list_users_roles()
      [%Role{}, ...]

  """
  def list_users_roles do
    Repo.all(Role)
  end

  @doc """
  Gets a single role.

  Raises `Ecto.NoResultsError` if the Role does not exist.

  ## Examples

      iex> get_role!(123)
      %Role{}

      iex> get_role!(456)
      ** (Ecto.NoResultsError)

  """
  def get_role!(id), do: Repo.get!(Role, id)

  @doc """
  Creates a role.

  ## Examples

      iex> create_role(%{field: value})
      {:ok, %Role{}}

      iex> create_role(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_role(attrs \\ %{}) do
    %Role{}
    |> Role.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a role.

  ## Examples

      iex> update_role(role, %{field: new_value})
      {:ok, %Role{}}

      iex> update_role(role, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_role(%Role{} = role, attrs) do
    role
    |> Role.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Role.

  ## Examples

      iex> delete_role(role)
      {:ok, %Role{}}

      iex> delete_role(role)
      {:error, %Ecto.Changeset{}}

  """
  def delete_role(%Role{} = role) do
    Repo.delete(role)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking role changes.

  ## Examples

      iex> change_role(role)
      %Ecto.Changeset{source: %Role{}}

  """
  def change_role(%Role{} = role) do
    Role.changeset(role, %{})
  end
end
