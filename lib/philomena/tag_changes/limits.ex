defmodule Philomena.TagChanges.Limits do
  @moduledoc """
  Tag change limits for anonymous users.
  """

  @tag_changes_per_ten_minutes 50
  @rating_changes_per_ten_minutes 1
  @ten_minutes_in_seconds 10 * 60

  @doc """
  Determine if the current user and IP can make any tag changes at all.

  The user may be limited due to making more than 50 tag changes in the past 10 minutes.
  Should be used in tandem with `update_tag_count_after_update/3`.

  ## Examples

      iex> limited_for_tag_count?(%User{}, %Postgrex.INET{})
      false

      iex> limited_for_tag_count?(%User{}, %Postgrex.INET{}, 72)
      true

  """
  def limited_for_tag_count?(user, ip, additional \\ 0) do
    check_limit(user, tag_count_key_for_ip(ip), @tag_changes_per_ten_minutes, additional)
  end

  @doc """
  Determine if the current user and IP can make rating tag changes.

  The user may be limited due to making more than one rating tag change in the past 10 minutes.
  Should be used in tandem with `update_rating_count_after_update/3`.

  ## Examples

      iex> limited_for_rating_count?(%User{}, %Postgrex.INET{})
      false

      iex> limited_for_rating_count?(%User{}, %Postgrex.INET{}, 2)
      true

  """
  def limited_for_rating_count?(user, ip) do
    check_limit(user, rating_count_key_for_ip(ip), @rating_changes_per_ten_minutes, 0)
  end

  @doc """
  Post-transaction update for successful tag changes.

  Should be used in tandem with `limited_for_tag_count?/2`.

  ## Examples

      iex> update_tag_count_after_update(%User{}, %Postgrex.INET{}, 25)
      :ok

  """
  def update_tag_count_after_update(user, ip, amount) do
    increment_counter(user, tag_count_key_for_ip(ip), amount, @ten_minutes_in_seconds)
  end

  @doc """
  Post-transaction update for successful rating tag changes.

  Should be used in tandem with `limited_for_rating_count?/2`.

  ## Examples

      iex> update_rating_count_after_update(%User{}, %Postgrex.INET{}, 1)
      :ok

  """
  def update_rating_count_after_update(user, ip, amount) do
    increment_counter(user, rating_count_key_for_ip(ip), amount, @ten_minutes_in_seconds)
  end

  defp check_limit(user, key, limit, additional) do
    if considered_for_limit?(user) do
      amt = Redix.command!(:redix, ["GET", key]) || 0
      amt + additional >= limit
    else
      false
    end
  end

  defp increment_counter(user, key, amount, expiration) do
    if considered_for_limit?(user) do
      Redix.pipeline!(:redix, [
        ["INCRBY", key, amount],
        ["EXPIRE", key, expiration]
      ])
    end

    :ok
  end

  defp considered_for_limit?(user) do
    is_nil(user) or not user.verified
  end

  defp tag_count_key_for_ip(ip) do
    "rltcn:#{ip}"
  end

  defp rating_count_key_for_ip(ip) do
    "rltcr:#{ip}"
  end
end
