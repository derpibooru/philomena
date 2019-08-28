defmodule Philomena.Vpns do
  @moduledoc """
  The Vpns context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Vpns.Vpn

  @doc """
  Returns the list of vpns.

  ## Examples

      iex> list_vpns()
      [%Vpn{}, ...]

  """
  def list_vpns do
    Repo.all(Vpn)
  end

  @doc """
  Gets a single vpn.

  Raises `Ecto.NoResultsError` if the Vpn does not exist.

  ## Examples

      iex> get_vpn!(123)
      %Vpn{}

      iex> get_vpn!(456)
      ** (Ecto.NoResultsError)

  """
  def get_vpn!(id), do: Repo.get!(Vpn, id)

  @doc """
  Creates a vpn.

  ## Examples

      iex> create_vpn(%{field: value})
      {:ok, %Vpn{}}

      iex> create_vpn(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_vpn(attrs \\ %{}) do
    %Vpn{}
    |> Vpn.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a vpn.

  ## Examples

      iex> update_vpn(vpn, %{field: new_value})
      {:ok, %Vpn{}}

      iex> update_vpn(vpn, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_vpn(%Vpn{} = vpn, attrs) do
    vpn
    |> Vpn.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Vpn.

  ## Examples

      iex> delete_vpn(vpn)
      {:ok, %Vpn{}}

      iex> delete_vpn(vpn)
      {:error, %Ecto.Changeset{}}

  """
  def delete_vpn(%Vpn{} = vpn) do
    Repo.delete(vpn)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking vpn changes.

  ## Examples

      iex> change_vpn(vpn)
      %Ecto.Changeset{source: %Vpn{}}

  """
  def change_vpn(%Vpn{} = vpn) do
    Vpn.changeset(vpn, %{})
  end
end
