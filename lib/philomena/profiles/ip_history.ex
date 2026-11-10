defmodule Philomena.Profiles.IpHistory do
  @moduledoc """
  A paginated user's IP history and the bounded cross-references for the IPs on
  the current page.
  """

  alias Philomena.UserIps.UserIp
  alias Philomena.Users.User

  @enforce_keys [:user, :user_ips, :other_users]
  defstruct [:user, :user_ips, :other_users]

  @type t :: %__MODULE__{
          user: User.t(),
          user_ips: Scrivener.Page.t(UserIp.t()),
          other_users: %{optional(Postgrex.INET.t()) => [UserIp.t()]}
        }
end
