defmodule Philomena.AttributionFixtures do
  @moduledoc """
  Shared request attribution for fixtures.

  Several context `create_*` functions take an attribution keyword list in
  the shape built by `PhilomenaWeb.UserAttributionPlug` (`:ip`,
  `:fingerprint`, `:user`). This module centralizes that shape so fixtures
  stay consistent with each other (and with `Philomena.ImagesFixtures`,
  which hardcodes the same values on the image row).
  """

  alias Philomena.Attribution.Actor

  @doc """
  Attribution keyword list for the given `user` (`nil` for anonymous).
  """
  def attribution(user \\ nil) do
    [
      ip: %Postgrex.INET{address: {203, 0, 113, 1}, netmask: 32},
      fingerprint: "d015c342859dde3",
      user: user
    ]
  end

  @doc """
  The same attribution as `attribution/1`, as the typed
  `Philomena.Attribution.Actor` struct that actor-first context functions
  take.

  The `:ban` and `:fingerprint` options override those struct fields. The ban
  defaults to nil, matching how `PhilomenaWeb.UserAttributionPlug` builds the
  actor when the request carries no active ban.
  """
  def actor(user \\ nil, opts \\ []) do
    attrs = attribution(user)

    %Philomena.Attribution.Actor{
      ip: Keyword.get(opts, :ip, attrs[:ip]),
      fingerprint: Keyword.get(opts, :fingerprint, attrs[:fingerprint]),
      user: attrs[:user],
      ban: Keyword.get(opts, :ban)
    }
  end

  @doc """
  Generates a random IP address for use in fixtures which track rate limiting.
  """
  def random_ip do
    ip = List.to_tuple(for <<u::integer-size(16) <- :crypto.strong_rand_bytes(16)>>, do: u)

    %Postgrex.INET{
      address: ip,
      netmask: 128
    }
  end

  @doc """
  Clears the Valkey tag-change rate-limit counters for the given attribution.

  Tag changes authored through `Philomena.Images.update_tags/3` bump the
  `rltcn:`/`rltcr:` counters, which `Philomena.TagChanges.Limits` scopes to the
  acting identity: `u:<user_id>` for a logged-in user, `i:<ip>` for an anonymous
  visitor (50 tag changes / 1 rating change per 10 minutes for
  anonymous/unverified users). The SQL sandbox does not roll Valkey back, so the
  counters accumulate across test runs (10-minute TTL) and eventually trip the
  limit. Tests that author tag changes with the shared `attribution/1` fixture
  must reset it in setup.

  When the attribution carries a user, both the `u:` (its actual scope) and the
  `i:` variants are cleared defensively so the helper is useful regardless of
  which path a test exercises; an anonymous attribution clears only `i:`.
  """
  def reset_tag_change_limits(attrs \\ attribution()) do
    ip = attrs[:ip]

    keys =
      case attrs[:user] do
        nil ->
          ["rltcn:i:#{ip}", "rltcr:i:#{ip}"]

        user ->
          ["rltcn:u:#{user.id}", "rltcr:u:#{user.id}", "rltcn:i:#{ip}", "rltcr:i:#{ip}"]
      end

    Redix.command!(:redix, ["DEL" | keys])
    :ok
  end

  @doc """
  The Valkey counter key `Philomena.RateLimiter` scopes to `actor` for
  `operation` - `u:<user_id>` when signed in, `i:<ip>` when anonymous (the same
  scheme `Philomena.RateLimiter.key/2` uses privately).
  """
  def rate_limit_key(%Actor{user: nil, ip: ip}, operation), do: "rl:#{operation}:i:#{ip}"
  def rate_limit_key(%Actor{user: user}, operation), do: "rl:#{operation}:u:#{user.id}"

  @doc """
  Reads `actor`'s raw `Philomena.RateLimiter` counter for `operation` from
  Valkey (a decimal string, or `nil` when nothing has been recorded).
  """
  def rate_limit_count(%Actor{} = actor, operation) do
    Redix.command!(:redix, ["GET", rate_limit_key(actor, operation)])
  end

  @doc """
  Registers `on_exit` cleanup that deletes `actor`'s `Philomena.RateLimiter`
  counter for `operation`.

  The SQL sandbox does not roll Valkey back, so any test that lets a counter be
  recorded (or primes one itself) must clear it or it leaks into later tests and
  runs. Use this when the function under test records the counter for you; use
  `exceed_rate_limit/2` when you need to prime it over the limit.
  """
  def track_rate_limit(%Actor{} = actor, operation) do
    key = rate_limit_key(actor, operation)
    ExUnit.Callbacks.on_exit(fn -> Redix.command!(:redix, ["DEL", key]) end)
    :ok
  end

  @doc """
  Primes `actor`'s `Philomena.RateLimiter` counter for `operation` past the
  limit so the next `record_action/3` refuses it, and registers `on_exit`
  cleanup of the key.

  The check boundary is inclusive at a limit of 1, so a counter of 2 is over the
  limit. This only makes sense for a non-exempt actor (a plain user or an
  anonymous IP); staff and `bypass_rate_limits` users are never limited.
  """
  def exceed_rate_limit(%Actor{} = actor, operation) do
    track_rate_limit(actor, operation)
    Redix.command!(:redix, ["SET", rate_limit_key(actor, operation), "2"])
    :ok
  end
end
