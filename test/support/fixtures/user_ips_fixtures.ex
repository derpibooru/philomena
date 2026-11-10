defmodule Philomena.UserIpsFixtures do
  @moduledoc """
  Test helpers for `m:Philomena.UserIps.UserIp` rows.

  `UserIp` rows are only ever written by `UserAttributionPlug` internals (the
  schema changeset casts nothing), so - like the commission directory tests -
  fixtures insert directly.
  """

  alias Philomena.Repo
  alias Philomena.UserIps.UserIp

  @doc """
  Casts a dotted-decimal / CIDR string to a `%Postgrex.INET{}`.
  """
  def inet(ip) do
    {:ok, inet} = EctoNetwork.INET.cast(ip)
    inet
  end

  @doc """
  Inserts a `UserIp` row associating `user` with `ip` (a string, default
  `"203.0.113.1"`).
  """
  def user_ip_fixture(user, ip \\ "203.0.113.1") do
    Repo.insert!(%UserIp{
      user_id: user.id,
      ip: inet(ip),
      uses: 1
    })
  end
end
