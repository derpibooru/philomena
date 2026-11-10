defmodule Philomena.ModerationLogs do
  @moduledoc """
  Append-only audit records for staff actions.

  Moderated database changes should compose `put_log/6` into their owning
  `Ecto.Multi`, so failure to persist the audit record rolls the action back.
  The actor-scoped listing exposes only the retained two-week window.
  """

  import Ecto.Query, warn: false
  import Philomena.Authorization, only: [authorize: 3]

  alias Philomena.Multi
  alias Philomena.Attribution.Actor
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Repo
  alias Philomena.Users.User

  defp log_changeset(%User{} = user, type, subject_path, body) do
    %ModerationLog{user_id: user.id}
    |> ModerationLog.changeset(%{type: type, subject_path: subject_path, body: body})
  end

  defp list_moderation_logs(pagination) do
    ModerationLog
    |> where([ml], ml.created_at >= ago(2, "week"))
    |> preload(:user)
    |> order_by(desc: :created_at, desc: :id)
    |> Repo.paginate(pagination)
  end

  @doc """
  Returns the retained, paginated moderation logs visible to `actor`.

  Only records from the last two weeks are returned, newest first. Access is
  authorized with `:index` on `ModerationLog`.

  ## Examples

      iex> list_moderation_logs(admin, pagination)
      {:ok, %Scrivener.Page{}}

      iex> list_moderation_logs(user, pagination)
      {:error, :unauthorized}

  """
  @spec list_moderation_logs(Actor.t(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t(ModerationLog.t())} | {:error, :unauthorized}
  def list_moderation_logs(%Actor{} = actor, pagination) do
    with :ok <- authorize(actor, :index, ModerationLog) do
      {:ok, list_moderation_logs(pagination)}
    end
  end

  @doc """
  Adds an attributed audit-log insert to `multi` under `step`.

  The returned `Ecto.Multi` does no work until its owner transacts it. A failed
  log changeset therefore rolls back every preceding database step. Build
  `subject_path` with `Philomena.ModerationLogs.Paths` when a canonical helper
  exists.

  ## Examples

      iex> put_log(multi, :log, actor, "User:update", "/profiles/name", "Updated user")
      %Ecto.Multi{}

  """
  @spec put_log(
          multi :: Multi.t(),
          step :: Multi.name(),
          actor :: Actor.t(),
          type :: String.t(),
          subject_path :: String.t(),
          body :: String.t()
        ) ::
          Multi.t()
  def put_log(%Multi{} = multi, step, %Actor{user: %User{} = user}, type, subject_path, body)
      when is_binary(body) do
    Multi.insert(multi, step, log_changeset(user, type, subject_path, body))
  end

  @doc ~S"""
  Adds an audit-log insert whose attributes are derived from prior Multi changes.

  `callback` receives the completed changes and must return
  `{type, subject_path, body}`. Use this form when the audited subject is
  created by an earlier Multi step.

  ## Examples

      iex> put_log(multi, :log, actor, fn %{user: user} ->
      ...>   {"User:create", "/profiles/#{user.name}", "Created user"}
      ...> end)
      %Ecto.Multi{}

  """
  @spec put_log(
          multi :: Multi.t(),
          step :: Multi.name(),
          actor :: Actor.t(),
          callback :: (Ecto.Multi.changes() -> {String.t(), String.t(), String.t()})
        ) ::
          Multi.t()
  def put_log(%Multi{} = multi, step, %Actor{user: user}, callback)
      when is_function(callback, 1) do
    Multi.run(multi, step, fn repo, changes ->
      {type, subject_path, body} = callback.(changes)

      user
      |> log_changeset(type, subject_path, body)
      |> repo.insert()
    end)
  end

  @doc """
  Inserts an audit record within the caller's ambient Repo transaction.

  Transactional mutations should prefer `put_log/6`.

  ## Examples

      iex> create_moderation_log(actor, "User:update", "/profiles/name", "Updated user")
      {:ok, %ModerationLog{}}

  """
  @spec create_moderation_log(Actor.t() | User.t(), String.t(), String.t(), String.t()) ::
          {:ok, ModerationLog.t()} | {:error, Ecto.Changeset.t()}
  def create_moderation_log(actor, type, subject_path, body)

  def create_moderation_log(%Actor{} = actor, type, subject_path, body) do
    create_moderation_log(actor.user, type, subject_path, body)
  end

  def create_moderation_log(%User{} = user, type, subject_path, body) do
    user
    |> log_changeset(type, subject_path, body)
    |> Repo.insert()
  end

  @doc """
  Removes moderation logs older than the two-week retention window.

  The release task raises on database failure.

  ## Examples

      iex> cleanup!()
      {31, nil}

  """
  @spec cleanup!() :: {non_neg_integer(), nil}
  def cleanup! do
    ModerationLog
    |> where([ml], ml.created_at < ago(2, "week"))
    |> Repo.delete_all()
  end
end
