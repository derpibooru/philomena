defmodule Philomena.PollOptions do
  @moduledoc """
  The PollOptions context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.PollOptions.PollOption

  @doc """
  Returns the list of poll_options.

  ## Examples

      iex> list_poll_options()
      [%PollOption{}, ...]

  """
  def list_poll_options do
    Repo.all(PollOption)
  end

  @doc """
  Gets a single poll_option.

  Raises `Ecto.NoResultsError` if the Poll option does not exist.

  ## Examples

      iex> get_poll_option!(123)
      %PollOption{}

      iex> get_poll_option!(456)
      ** (Ecto.NoResultsError)

  """
  def get_poll_option!(id), do: Repo.get!(PollOption, id)

  @doc """
  Creates a poll_option.

  ## Examples

      iex> create_poll_option(%{field: value})
      {:ok, %PollOption{}}

      iex> create_poll_option(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_poll_option(attrs \\ %{}) do
    %PollOption{}
    |> PollOption.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a poll_option.

  ## Examples

      iex> update_poll_option(poll_option, %{field: new_value})
      {:ok, %PollOption{}}

      iex> update_poll_option(poll_option, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_poll_option(%PollOption{} = poll_option, attrs) do
    poll_option
    |> PollOption.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a PollOption.

  ## Examples

      iex> delete_poll_option(poll_option)
      {:ok, %PollOption{}}

      iex> delete_poll_option(poll_option)
      {:error, %Ecto.Changeset{}}

  """
  def delete_poll_option(%PollOption{} = poll_option) do
    Repo.delete(poll_option)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking poll_option changes.

  ## Examples

      iex> change_poll_option(poll_option)
      %Ecto.Changeset{source: %PollOption{}}

  """
  def change_poll_option(%PollOption{} = poll_option) do
    PollOption.changeset(poll_option, %{})
  end
end
