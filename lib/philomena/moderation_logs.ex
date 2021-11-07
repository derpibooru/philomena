defmodule Philomena.ModerationLogs do
  @moduledoc """
  The ModerationLogs context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.ModerationLogs.ModerationLog

  @doc """
  Returns the list of moderation_logs.

  ## Examples

      iex> list_moderation_logs()
      [%ModerationLog{}, ...]

  """
  def list_moderation_logs(conn) do
    ModerationLog
    |> where([ml], ml.created_at > ago(2, "week"))
    |> preload(:user)
    |> order_by(desc: :created_at)
    |> Repo.paginate(conn.assigns.scrivener)
  end

  @doc """
  Gets a single moderation_log.

  Raises `Ecto.NoResultsError` if the Moderation log does not exist.

  ## Examples

      iex> get_moderation_log!(123)
      %ModerationLog{}

      iex> get_moderation_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_moderation_log!(id), do: Repo.get!(ModerationLog, id)

  @doc """
  Creates a moderation_log.

  ## Examples

      iex> create_moderation_log(%{field: value})
      {:ok, %ModerationLog{}}

      iex> create_moderation_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_moderation_log(user, type, subject_path, body) do
    %ModerationLog{user_id: user.id}
    |> ModerationLog.changeset(%{type: type, subject_path: subject_path, body: body})
    |> Repo.insert()
  end

  @doc """
  Deletes a moderation_log.

  ## Examples

      iex> delete_moderation_log(moderation_log)
      {:ok, %ModerationLog{}}

      iex> delete_moderation_log(moderation_log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_moderation_log(%ModerationLog{} = moderation_log) do
    Repo.delete(moderation_log)
  end
end
