defmodule Philomena.UserNameChanges do
  @moduledoc """
  The UserNameChanges context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.UserNameChanges.UserNameChange

  @doc """
  Returns the list of user_name_changes.

  ## Examples

      iex> list_user_name_changes()
      [%UserNameChange{}, ...]

  """
  def list_user_name_changes do
    Repo.all(UserNameChange)
  end

  @doc """
  Gets a single user_name_change.

  Raises `Ecto.NoResultsError` if the User name change does not exist.

  ## Examples

      iex> get_user_name_change!(123)
      %UserNameChange{}

      iex> get_user_name_change!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_name_change!(id), do: Repo.get!(UserNameChange, id)

  @doc """
  Creates a user_name_change.

  ## Examples

      iex> create_user_name_change(%{field: value})
      {:ok, %UserNameChange{}}

      iex> create_user_name_change(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_name_change(attrs \\ %{}) do
    %UserNameChange{}
    |> UserNameChange.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_name_change.

  ## Examples

      iex> update_user_name_change(user_name_change, %{field: new_value})
      {:ok, %UserNameChange{}}

      iex> update_user_name_change(user_name_change, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_name_change(%UserNameChange{} = user_name_change, attrs) do
    user_name_change
    |> UserNameChange.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a UserNameChange.

  ## Examples

      iex> delete_user_name_change(user_name_change)
      {:ok, %UserNameChange{}}

      iex> delete_user_name_change(user_name_change)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_name_change(%UserNameChange{} = user_name_change) do
    Repo.delete(user_name_change)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_name_change changes.

  ## Examples

      iex> change_user_name_change(user_name_change)
      %Ecto.Changeset{source: %UserNameChange{}}

  """
  def change_user_name_change(%UserNameChange{} = user_name_change) do
    UserNameChange.changeset(user_name_change, %{})
  end
end
