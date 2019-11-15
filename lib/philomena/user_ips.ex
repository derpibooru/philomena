defmodule Philomena.UserIps do
  @moduledoc """
  The UserIps context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.UserIps.UserIp

  @doc """
  Returns the list of user_ips.

  ## Examples

      iex> list_user_ips()
      [%UserIp{}, ...]

  """
  def list_user_ips do
    Repo.all(UserIp)
  end

  @doc """
  Gets a single user_ip.

  Raises `Ecto.NoResultsError` if the User ip does not exist.

  ## Examples

      iex> get_user_ip!(123)
      %UserIp{}

      iex> get_user_ip!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_ip!(id), do: Repo.get!(UserIp, id)

  @doc """
  Creates a user_ip.

  ## Examples

      iex> create_user_ip(%{field: value})
      {:ok, %UserIp{}}

      iex> create_user_ip(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_ip(attrs \\ %{}) do
    %UserIp{}
    |> UserIp.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_ip.

  ## Examples

      iex> update_user_ip(user_ip, %{field: new_value})
      {:ok, %UserIp{}}

      iex> update_user_ip(user_ip, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_ip(%UserIp{} = user_ip, attrs) do
    user_ip
    |> UserIp.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a UserIp.

  ## Examples

      iex> delete_user_ip(user_ip)
      {:ok, %UserIp{}}

      iex> delete_user_ip(user_ip)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_ip(%UserIp{} = user_ip) do
    Repo.delete(user_ip)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_ip changes.

  ## Examples

      iex> change_user_ip(user_ip)
      %Ecto.Changeset{source: %UserIp{}}

  """
  def change_user_ip(%UserIp{} = user_ip) do
    UserIp.changeset(user_ip, %{})
  end
end
