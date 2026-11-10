defmodule Philomena.Polls do
  @moduledoc """
  Poll forms, updates, and shared services for voting.
  """

  import Ecto.Query, warn: false
  import Philomena.Authorization, only: [verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Attribution.Actor
  alias Philomena.Loader
  alias Philomena.Polls.Poll
  alias Philomena.Multi
  alias Philomena.Forums
  alias Philomena.Topics
  alias Philomena.Topics.Topic

  @doc """
  Loads a poll through its topic.

  This service is shared with `Philomena.PollVotes`; callers cannot load
  a poll independently of an authorized parent chain.

  ## Examples

      iex> load_topic_poll(topic_with_poll)
      {:ok, %Poll{}}

      iex> load_topic_poll(topic_without_poll)
      {:error, :not_found}

  """
  @spec load_topic_poll(Topic.t()) ::
          {:ok, Poll.t()} | {:error, :not_found}
  def load_topic_poll(%Topic{} = topic) do
    Poll
    |> where([poll], poll.topic_id == ^topic.id)
    |> preload([:options, topic: :forum])
    |> Loader.one()
  end

  @doc """
  Loads an authorized poll edit form.

  A banned actor is refused; a missing fingerprint is left to `update_poll/4`.
  Existing options are included in the form.

  ## Examples

      iex> edit_poll(moderator_actor, "dis", "favorite-pony")
      {:ok, %Ecto.Changeset{}}

  """
  @spec edit_poll(Actor.t(), String.t(), String.t()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :not_found | :unauthorized}
  def edit_poll(%Actor{} = actor, forum_slug, topic_slug) do
    with :ok <- verify_not_banned(actor),
         {:ok, forum} <- Forums.show_forum(actor, forum_slug),
         {:ok, topic} <- Topics.show_forum_topic(actor, forum, topic_slug, :edit_poll),
         {:ok, poll} <- load_topic_poll(topic) do
      {:ok, Poll.changeset(poll)}
    end
  end

  @doc """
  Updates the poll beneath the authorized route topic.

  The poll is row-locked while it and its options update transactionally. Invalid
  close times, vote methods, titles, or option sets return a form carrying the
  rejected changeset. Once voting has started, the vote method and options are
  immutable so existing votes retain their meaning; the title and end time may
  still be changed.

  ## Examples

      iex> update_poll(moderator_actor, "dis", "favorite-pony", attrs)
      {:ok, %Poll{}}

      iex> update_poll(moderator_actor, "dis", "favorite-pony", invalid_attrs)
      {:error, %Ecto.Changeset{}}

  """
  @spec update_poll(Actor.t(), String.t(), String.t(), map()) ::
          {:ok, Poll.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :not_found | :unauthorized}
  def update_poll(%Actor{} = actor, forum_slug, topic_slug, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, forum} <- Forums.show_forum(actor, forum_slug),
         {:ok, topic} <- Topics.show_forum_topic(actor, forum, topic_slug, :update_poll),
         {:ok, poll} <- load_topic_poll(topic) do
      poll_query =
        Poll
        |> where(id: ^poll.id)
        |> preload([:options, topic: :forum])

      Multi.new()
      |> Multi.lock_one(:locked_poll, poll_query)
      |> Multi.update(:poll, fn %{locked_poll: poll} -> Poll.changeset(poll, attrs) end)
      |> Multi.transact()
      |> case do
        {:ok, %{poll: %Poll{} = poll}} ->
          {:ok, poll}

        {:error, :poll, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Adds a total  vote adjustment for `poll_id` to `multi`.

  PollVotes uses this transaction step after inserting or deleting votes. The
  poll row is expected to have been locked by the caller before this step is
  composed.
  """
  @spec put_total_votes_delta(Multi.t(), Multi.name(), integer(), (Multi.changes() -> integer())) ::
          Multi.t()
  def put_total_votes_delta(%Multi{} = multi, step, poll_id, amount_callback)
      when is_integer(poll_id) do
    Multi.run(multi, step, fn repo, changes ->
      amount = amount_callback.(changes)

      {:ok, repo.update_all(where(Poll, id: ^poll_id), inc: [total_votes: amount])}
    end)
  end

  @doc """
  Returns whether a loaded poll is accepting votes at `now`.

  The close instant itself is inactive.

  ## Examples

      iex> active?(poll, DateTime.utc_now())
      true

  """
  @spec active?(Poll.t() | nil, DateTime.t()) :: boolean()
  def active?(poll, now \\ DateTime.utc_now())

  def active?(%Poll{active_until: %DateTime{} = active_until}, %DateTime{} = now),
    do: DateTime.compare(active_until, now) == :gt

  def active?(_poll, _now), do: false
end
