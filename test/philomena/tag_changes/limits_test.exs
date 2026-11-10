defmodule Philomena.TagChanges.LimitsTest do
  use Philomena.DataCase, async: false

  alias Philomena.TagChanges.Limits
  alias Philomena.Users.User

  @tag_limit 50
  @rating_limit 1

  defp user(verified \\ false),
    do: %User{id: System.unique_integer([:positive]), verified: verified}

  defp unique_ip do
    n = System.unique_integer([:positive])
    %Postgrex.INET{address: {203, 0, rem(div(n, 254), 254) + 1, rem(n, 254) + 1}, netmask: 32}
  end

  defp track(user, ip) do
    on_exit(fn ->
      scope = if user, do: "u:#{user.id}", else: "i:#{ip}"
      Redix.command!(:redix, ["DEL", "rltcn:#{scope}", "rltcr:#{scope}"])
    end)
  end

  test "tag and rating reservations use their inclusive limits" do
    user = user()
    ip = unique_ip()
    track(user, ip)

    assert Limits.record_action(user, ip, @tag_limit, 0) == :ok
    assert Limits.record_action(user, ip, 1, 0) == {:error, :rate_limited}
    assert Limits.record_action(user, ip, 0, @rating_limit) == :ok
    assert Limits.record_action(user, ip, 0, 1) == {:error, :rate_limited}
  end

  test "rollback releases both reservations" do
    user = user()
    ip = unique_ip()
    track(user, ip)

    assert Limits.record_action(user, ip, 2, 1) == :ok
    assert Limits.rollback_action(user, ip, 2, 1) == :ok
    assert Limits.record_action(user, ip, @tag_limit, @rating_limit) == :ok
  end

  test "concurrent tag reservations above the limit are rejected" do
    user = user()
    ip = unique_ip()
    track(user, ip)

    results =
      for _ <- 1..2 do
        Task.async(fn -> Limits.record_action(user, ip, 30, 0) end)
      end
      |> Enum.map(&Task.await(&1, 5_000))

    assert Enum.count(results, &(&1 == :ok)) == 1
    assert Enum.count(results, &(&1 == {:error, :rate_limited})) == 1
    assert Redix.command!(:redix, ["GET", "rltcn:u:#{user.id}"]) == "30"
  end

  test "anonymous requests share their IP bucket" do
    ip = unique_ip()
    track(nil, ip)

    assert Limits.record_action(nil, ip, @tag_limit, 0) == :ok
    assert Limits.record_action(nil, ip, 1, 0) == {:error, :rate_limited}
  end

  for attrs <- [
        [verified: true],
        [role: "admin"],
        [role: "moderator"],
        [role: "assistant"],
        [bypass_rate_limits: true]
      ] do
    test "#{inspect(attrs)} users are exempt" do
      user = struct!(%User{id: System.unique_integer([:positive])}, unquote(attrs))
      ip = unique_ip()
      track(user, ip)

      assert Limits.record_action(user, ip, @tag_limit * 10, @rating_limit * 10) == :ok
      assert Limits.rollback_action(user, ip, 1, 1) == :ok
      assert Redix.command!(:redix, ["GET", "rltcn:u:#{user.id}"]) == nil
    end
  end
end
