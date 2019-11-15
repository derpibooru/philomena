defmodule Philomena.UserStatistics do
  @moduledoc """
  The UserStatistics context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.UserStatistics.UserStatistic

  @doc """
  Returns the list of user_statistics.

  ## Examples

      iex> list_user_statistics()
      [%UserStatistic{}, ...]

  """
  def list_user_statistics do
    Repo.all(UserStatistic)
  end

  @doc """
  Gets a single user_statistic.

  Raises `Ecto.NoResultsError` if the User statistic does not exist.

  ## Examples

      iex> get_user_statistic!(123)
      %UserStatistic{}

      iex> get_user_statistic!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_statistic!(id), do: Repo.get!(UserStatistic, id)

  @doc """
  Creates a user_statistic.

  ## Examples

      iex> create_user_statistic(%{field: value})
      {:ok, %UserStatistic{}}

      iex> create_user_statistic(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_statistic(attrs \\ %{}) do
    %UserStatistic{}
    |> UserStatistic.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_statistic.

  ## Examples

      iex> update_user_statistic(user_statistic, %{field: new_value})
      {:ok, %UserStatistic{}}

      iex> update_user_statistic(user_statistic, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_statistic(%UserStatistic{} = user_statistic, attrs) do
    user_statistic
    |> UserStatistic.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a UserStatistic.

  ## Examples

      iex> delete_user_statistic(user_statistic)
      {:ok, %UserStatistic{}}

      iex> delete_user_statistic(user_statistic)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_statistic(%UserStatistic{} = user_statistic) do
    Repo.delete(user_statistic)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_statistic changes.

  ## Examples

      iex> change_user_statistic(user_statistic)
      %Ecto.Changeset{source: %UserStatistic{}}

  """
  def change_user_statistic(%UserStatistic{} = user_statistic) do
    UserStatistic.changeset(user_statistic, %{})
  end
end
