defmodule Philomena.UserFingerprints.FingerprintProfile do
  @moduledoc """
  The assembled fingerprint profile page: the fingerprint, the users seen with
  it, and the fingerprint bans matching it.
  """

  alias Philomena.UserFingerprints.UserFingerprint
  alias Philomena.Bans.Fingerprint

  @enforce_keys [:fingerprint, :user_fingerprints, :fingerprint_bans]
  defstruct [:fingerprint, :user_fingerprints, :fingerprint_bans]

  @type t :: %__MODULE__{
          fingerprint: String.t(),
          user_fingerprints: [UserFingerprint.t()],
          fingerprint_bans: [Fingerprint.t()]
        }
end
