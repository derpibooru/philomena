defmodule Philomena.TagChanges.Limits do
  @moduledoc """
  Tag change limits for anonymous and unverified users.

  Verified users are exempt entirely, as are staff (admins, moderators,
  assistants) and users with `bypass_rate_limits` set; see
  `considered_for_limit?/1`.
  """

  alias Philomena.Users.User

  @tag_changes_per_ten_minutes 50
  @rating_changes_per_ten_minutes 1
  @ten_minutes_in_seconds 10 * 60

  @doc """
  Reserve `tag_amount` tag changes and `rating_amount` rating changes for a
  transaction.

  The user may be limited due to making more than 50 tag changes or one rating
  change in the past 10 minutes. A reservation over either limit is undone
  before returning `{:error, :rate_limited}`.

  """
  @spec record_action(User.t() | nil, Postgrex.INET.t(), non_neg_integer(), non_neg_integer()) ::
          :ok | {:error, :rate_limited}
  def record_action(user, ip, tag_amount, rating_amount) do
    case increment_counter(
           user,
           tag_count_key(user, ip),
           tag_amount,
           @tag_changes_per_ten_minutes
         ) do
      {:error, :rate_limited} = error ->
        error

      {:ok, nil} ->
        case increment_counter(
               user,
               rating_count_key(user, ip),
               rating_amount,
               @rating_changes_per_ten_minutes
             ) do
          {:ok, nil} ->
            :ok

          {:error, :rate_limited} = error ->
            decrement_counter(tag_count_key(user, ip), tag_amount)
            error
        end
    end
  end

  @doc """
  Roll back the tag and rating reservations owned by a transaction.
  """
  @spec rollback_action(User.t() | nil, Postgrex.INET.t(), non_neg_integer(), non_neg_integer()) ::
          :ok
  def rollback_action(user, ip, tag_amount, rating_amount) do
    if considered_for_limit?(user) do
      decrement_counter(tag_count_key(user, ip), tag_amount)
      decrement_counter(rating_count_key(user, ip), rating_amount)
    else
      :ok
    end

    :ok
  end

  defp increment_counter(_user, _key, 0, _limit), do: {:ok, nil}

  defp increment_counter(user, key, amount, limit) do
    if considered_for_limit?(user) do
      count = Redix.command!(:redix, ["INCRBY", key, amount])

      if count <= limit do
        Redix.command!(:redix, ["EXPIRE", key, @ten_minutes_in_seconds])
        {:ok, nil}
      else
        decrement_counter(key, amount)
        {:error, :rate_limited}
      end
    else
      {:ok, nil}
    end
  end

  defp decrement_counter(_key, 0), do: :ok

  defp decrement_counter(key, amount) do
    Redix.command!(:redix, ["DECRBY", key, amount])
    :ok
  end

  # Staff and rate-limit-bypassing users are never limited; anonymous and
  # unverified users are.
  defp considered_for_limit?(nil), do: true
  defp considered_for_limit?(%{role: role}) when role in ~W(admin moderator assistant), do: false
  defp considered_for_limit?(%{bypass_rate_limits: true}), do: false
  defp considered_for_limit?(user), do: not user.verified

  defp tag_count_key(user, ip) do
    "rltcn:#{scope(user, ip)}"
  end

  defp rating_count_key(user, ip) do
    "rltcr:#{scope(user, ip)}"
  end

  defp scope(nil, ip), do: "i:#{ip}"
  defp scope(user, _ip), do: "u:#{user.id}"
end
