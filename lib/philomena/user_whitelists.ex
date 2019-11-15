defmodule Philomena.UserWhitelists do
  @moduledoc """
  The UserWhitelists context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.UserWhitelists.UserWhitelist

  @doc """
  Returns the list of user_whitelists.

  ## Examples

      iex> list_user_whitelists()
      [%UserWhitelist{}, ...]

  """
  def list_user_whitelists do
    Repo.all(UserWhitelist)
  end

  @doc """
  Gets a single user_whitelist.

  Raises `Ecto.NoResultsError` if the User whitelist does not exist.

  ## Examples

      iex> get_user_whitelist!(123)
      %UserWhitelist{}

      iex> get_user_whitelist!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_whitelist!(id), do: Repo.get!(UserWhitelist, id)

  @doc """
  Creates a user_whitelist.

  ## Examples

      iex> create_user_whitelist(%{field: value})
      {:ok, %UserWhitelist{}}

      iex> create_user_whitelist(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_whitelist(attrs \\ %{}) do
    %UserWhitelist{}
    |> UserWhitelist.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_whitelist.

  ## Examples

      iex> update_user_whitelist(user_whitelist, %{field: new_value})
      {:ok, %UserWhitelist{}}

      iex> update_user_whitelist(user_whitelist, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_whitelist(%UserWhitelist{} = user_whitelist, attrs) do
    user_whitelist
    |> UserWhitelist.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a UserWhitelist.

  ## Examples

      iex> delete_user_whitelist(user_whitelist)
      {:ok, %UserWhitelist{}}

      iex> delete_user_whitelist(user_whitelist)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_whitelist(%UserWhitelist{} = user_whitelist) do
    Repo.delete(user_whitelist)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_whitelist changes.

  ## Examples

      iex> change_user_whitelist(user_whitelist)
      %Ecto.Changeset{source: %UserWhitelist{}}

  """
  def change_user_whitelist(%UserWhitelist{} = user_whitelist) do
    UserWhitelist.changeset(user_whitelist, %{})
  end
end
