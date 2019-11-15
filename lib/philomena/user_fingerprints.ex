defmodule Philomena.UserFingerprints do
  @moduledoc """
  The UserFingerprints context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.UserFingerprints.UserFingerprint

  @doc """
  Returns the list of user_fingerprints.

  ## Examples

      iex> list_user_fingerprints()
      [%UserFingerprint{}, ...]

  """
  def list_user_fingerprints do
    Repo.all(UserFingerprint)
  end

  @doc """
  Gets a single user_fingerprint.

  Raises `Ecto.NoResultsError` if the User fingerprint does not exist.

  ## Examples

      iex> get_user_fingerprint!(123)
      %UserFingerprint{}

      iex> get_user_fingerprint!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_fingerprint!(id), do: Repo.get!(UserFingerprint, id)

  @doc """
  Creates a user_fingerprint.

  ## Examples

      iex> create_user_fingerprint(%{field: value})
      {:ok, %UserFingerprint{}}

      iex> create_user_fingerprint(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_fingerprint(attrs \\ %{}) do
    %UserFingerprint{}
    |> UserFingerprint.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_fingerprint.

  ## Examples

      iex> update_user_fingerprint(user_fingerprint, %{field: new_value})
      {:ok, %UserFingerprint{}}

      iex> update_user_fingerprint(user_fingerprint, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_fingerprint(%UserFingerprint{} = user_fingerprint, attrs) do
    user_fingerprint
    |> UserFingerprint.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a UserFingerprint.

  ## Examples

      iex> delete_user_fingerprint(user_fingerprint)
      {:ok, %UserFingerprint{}}

      iex> delete_user_fingerprint(user_fingerprint)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_fingerprint(%UserFingerprint{} = user_fingerprint) do
    Repo.delete(user_fingerprint)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_fingerprint changes.

  ## Examples

      iex> change_user_fingerprint(user_fingerprint)
      %Ecto.Changeset{source: %UserFingerprint{}}

  """
  def change_user_fingerprint(%UserFingerprint{} = user_fingerprint) do
    UserFingerprint.changeset(user_fingerprint, %{})
  end
end
