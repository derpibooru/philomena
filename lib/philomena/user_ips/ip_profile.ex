defmodule Philomena.UserIps.IpProfile do
  @moduledoc """
  The assembled IP profile page: the IP address, the users seen on it, and the
  subnet bans covering it.
  """

  alias Philomena.UserIps.UserIp
  alias Philomena.Bans.Subnet

  @enforce_keys [:ip, :user_ips, :subnet_bans]
  defstruct [:ip, :user_ips, :subnet_bans]

  @type t :: %__MODULE__{
          ip: Postgrex.INET.t(),
          user_ips: [UserIp.t()],
          subnet_bans: [Subnet.t()]
        }
end
