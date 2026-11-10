defmodule Philomena.RateLimiterTest do
  use Philomena.DataCase, async: false

  alias Philomena.Attribution.Actor
  alias Philomena.Multi
  alias Philomena.RateLimiter
  alias Philomena.Users.User

  defp user_actor(user_attrs \\ []) do
    user = struct!(%User{id: System.unique_integer([:positive])}, user_attrs)
    actor = %Actor{ip: unique_ip(), fingerprint: "d015c342859dde3", user: user}

    on_exit(fn -> Redix.command!(:redix, ["DEL", "rl:post_create:u:#{user.id}"]) end)
    actor
  end

  defp anonymous_actor do
    actor = %Actor{ip: unique_ip(), fingerprint: "d015c342859dde3", user: nil}

    on_exit(fn -> Redix.command!(:redix, ["DEL", "rl:post_create:i:#{actor.ip}"]) end)
    actor
  end

  defp unique_ip do
    n = System.unique_integer([:positive])
    %Postgrex.INET{address: {203, 0, rem(div(n, 254), 254) + 1, rem(n, 254) + 1}, netmask: 32}
  end

  test "an action reserves one slot and rollback releases it" do
    actor = user_actor()

    assert RateLimiter.record_action(actor, :post_create, 60) == :ok
    assert RateLimiter.rollback_action(actor, :post_create) == :ok
    assert RateLimiter.record_action(actor, :post_create, 60) == :ok
  end

  test "a failed transaction rolls back its reservation" do
    actor = user_actor()

    result =
      Multi.new()
      |> Multi.reserve_action(
        fn -> RateLimiter.record_action(actor, :post_create, 60) end,
        fn -> RateLimiter.rollback_action(actor, :post_create) end
      )
      |> Multi.run(:failure, fn _repo, _changes -> {:error, :boom} end)
      |> Multi.transact()

    assert {:error, :failure, :boom, _changes} = result
    assert Redix.command!(:redix, ["GET", "rl:post_create:u:#{actor.user.id}"]) == "0"
    assert RateLimiter.record_action(actor, :post_create, 60) == :ok
  end

  test "concurrent reservations above the limit are rejected immediately" do
    actor = anonymous_actor()

    results =
      for _ <- 1..10 do
        Task.async(fn -> RateLimiter.record_action(actor, :post_create, 60) end)
      end
      |> Enum.map(&Task.await(&1, 5_000))

    assert Enum.count(results, &(&1 == :ok)) == 2
    assert Enum.count(results, &(&1 == {:error, :rate_limited})) == 8
    assert Redix.command!(:redix, ["GET", "rl:post_create:i:#{actor.ip}"]) == "10"
  end

  describe "scoping and exemptions" do
    test "signed-in actors are scoped by user id" do
      actor = user_actor()
      other = %Actor{actor | user: %User{id: System.unique_integer([:positive])}}

      assert RateLimiter.record_action(actor, :post_create, 60) == :ok
      assert RateLimiter.record_action(other, :post_create, 60) == :ok
    end

    for role <- ~w(admin moderator assistant) do
      test "a #{role} records no counter" do
        actor = user_actor(role: unquote(role))

        assert RateLimiter.record_action(actor, :post_create, 60) == :ok
        assert RateLimiter.record_action(actor, :post_create, 60) == :ok
        assert Redix.command!(:redix, ["GET", "rl:post_create:u:#{actor.user.id}"]) == nil
      end
    end

    test "a bypass_rate_limits user records no counter" do
      actor = user_actor(bypass_rate_limits: true)

      assert RateLimiter.record_action(actor, :post_create, 60) == :ok
      assert Redix.command!(:redix, ["GET", "rl:post_create:u:#{actor.user.id}"]) == nil
    end
  end

  test "recording sets a TTL on the counter" do
    actor = user_actor()

    assert RateLimiter.record_action(actor, :post_create, 60) == :ok
    ttl = Redix.command!(:redix, ["TTL", "rl:post_create:u:#{actor.user.id}"])
    assert ttl > 0 and ttl <= 60
  end
end
