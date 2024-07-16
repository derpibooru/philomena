defmodule Philomena.ModerationLogs do
  @moduledoc """
  The ModerationLogs context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.ModerationLogs.ModerationLog

  @doc """
  Returns a paginated list of moderation logs as a `m:Scrivener.Page`.

  ## Examples

      iex> list_moderation_logs(page_size: 15)
      [%ModerationLog{}, ...]

  """
  def list_moderation_logs(pagination) do
    ModerationLog
    |> where([ml], ml.created_at >= ago(2, "week"))
    |> preload(:user)
    |> order_by(desc: :created_at)
    |> Repo.paginate(pagination)
  end

  @doc """
  Creates a moderation log.

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
  Removes moderation logs created more than 2 weeks ago.

  ## Examples

      iex> cleanup!()
      {31, nil}

  """
  def cleanup! do
    ModerationLog
    |> where([ml], ml.created_at < ago(2, "week"))
    |> Repo.delete_all()
  end
end
