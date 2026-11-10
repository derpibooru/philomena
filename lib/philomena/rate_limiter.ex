defmodule Philomena.RateLimiter do
  @moduledoc """
  Per-identity rate limiting for controller-facing write operations.

  Contexts reserve a rate-limited write by calling `record_action/3` before
  its transaction and call `rollback_action/2` if that transaction rolls back.
  Counters live in Valkey under a per-operation key scoped to the acting
  identity - the actor's user when signed in, otherwise its IP - and expire
  `window` seconds after each successful reservation.

  `record_action/3` uses Valkey's atomic increment reply to reserve a slot. A
  reservation over the inclusive limit is refused, so concurrent requests
  cannot all pass a separate check before any of them are recorded. With the
  inclusive limit of 1, two writes are allowed in a window and the third is
  refused. A reservation is decremented only when its transaction rolls back.
  Staff (admins, moderators, assistants) and users with `bypass_rate_limits`
  set are never limited and record no counters; see `considered_for_limit?/1`.
  """

  alias Philomena.Attribution.Actor
  alias Philomena.Users.User

  @key_prefix "rl:"
  @limit 1

  @doc """
  Reserve a rate-limited `operation` for `actor`.

  Increments the actor's counter for `operation` and starts its expiry
  `window`, in seconds. Exempt actors reserve nothing. A reservation over the
  limit returns `{:error, :rate_limited}` immediately.

  ## Examples

      iex> record_action(actor, :post_create, 15)
      :ok

  """
  @spec record_action(Actor.t(), atom(), pos_integer()) ::
          :ok | {:error, :rate_limited}
  def record_action(%Actor{} = actor, operation, window) do
    if considered_for_limit?(actor.user) do
      key = key(actor, operation)
      count = Redix.command!(redix_connection(), ["INCR", key])

      if count <= @limit + 1 do
        Redix.command!(redix_connection(), ["EXPIRE", key, window])
        :ok
      else
        {:error, :rate_limited}
      end
    else
      :ok
    end
  end

  @doc """
  Roll back a reservation made by `record_action/3`.

  This is intended to be called only when the transaction which owns the
  reservation rolls back. Exempt actors have no counter to decrement.

  ## Examples

      iex> rollback_action(actor, :post_create)
      :ok

  """
  @spec rollback_action(Actor.t(), atom()) :: :ok
  def rollback_action(%Actor{} = actor, operation) do
    if considered_for_limit?(actor.user) do
      rollback_counter(key(actor, operation), 1)
    end

    :ok
  end

  @doc """
  Deletes every rate limit counter.

  This maintenance service is used by development seeds. It is
  deliberately global and must not be called from request paths.

  ## Examples

      iex> reset_limits_globally!()
      :ok

  """
  @spec reset_limits_globally!() :: :ok
  def reset_limits_globally! do
    case Redix.command!(redix_connection(), ["KEYS", "#{@key_prefix}*"]) do
      [] ->
        :ok

      keys ->
        Redix.command!(redix_connection(), ["DEL" | keys])
    end

    :ok
  end

  # Staff and rate-limit-bypassing users are never limited; everyone else,
  # anonymous or signed in, is.
  defp considered_for_limit?(nil), do: true

  defp considered_for_limit?(%User{role: role}) when role in ~w(admin moderator assistant),
    do: false

  defp considered_for_limit?(%User{bypass_rate_limits: true}), do: false
  defp considered_for_limit?(%User{}), do: true

  defp key(%Actor{} = actor, operation), do: "#{@key_prefix}#{operation}:#{scope(actor)}"

  defp scope(%Actor{user: nil, ip: ip}), do: "i:#{ip}"
  defp scope(%Actor{user: user}), do: "u:#{user.id}"

  defp rollback_counter(key, amount) do
    Redix.command!(redix_connection(), ["DECRBY", key, amount])
    :ok
  end

  defp redix_connection, do: :redix
end
