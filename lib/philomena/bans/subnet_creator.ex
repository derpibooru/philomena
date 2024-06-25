defmodule Philomena.Bans.SubnetCreator do
  @moduledoc """
  Handles automatic creation of subnet bans for an input user ban.

  This prevents trivial ban evasion with the creation of a new account from the same address.
  The user must work around or wait out the subnet ban first.
  """

  alias Philomena.UserIps
  alias Philomena.Bans

  @doc """
  Creates a subnet ban for the given user's last known IP address.

  Returns `{:ok, ban}`, `{:ok, nil}`, or `{:error, changeset}`. The return value is
  suitable for use as the return value to an `Ecto.Multi.run/3` callback.
  """
  def create_for_user(creator, user_id, attrs) do
    ip = UserIps.get_ip_for_user(user_id)

    if ip do
      Bans.create_subnet(creator, Map.put(attrs, "specification", UserIps.masked_ip(ip)))
    else
      {:ok, nil}
    end
  end
end
