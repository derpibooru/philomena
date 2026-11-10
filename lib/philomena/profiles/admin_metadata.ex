defmodule Philomena.Profiles.AdminMetadata do
  @moduledoc """
  Sensitive account metadata displayed alongside a user's profile for an
  authorized staff viewer.
  """

  alias Philomena.Filters.Filter
  alias Philomena.UserFingerprints.UserFingerprint
  alias Philomena.UserIps.UserIp

  @enforce_keys [:filter, :last_ip, :last_fingerprint]
  defstruct [:filter, :last_ip, :last_fingerprint]

  @type t :: %__MODULE__{
          filter: Filter.t() | nil,
          last_ip: UserIp.t() | nil,
          last_fingerprint: UserFingerprint.t() | nil
        }
end
