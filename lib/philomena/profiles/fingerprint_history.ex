defmodule Philomena.Profiles.FingerprintHistory do
  @moduledoc """
  A paginated user's browser-fingerprint history and the bounded
  cross-references for fingerprints on the current page.
  """

  alias Philomena.UserFingerprints.UserFingerprint
  alias Philomena.Users.User

  @enforce_keys [:user, :user_fingerprints, :other_users]
  defstruct [:user, :user_fingerprints, :other_users]

  @type t :: %__MODULE__{
          user: User.t(),
          user_fingerprints: Scrivener.Page.t(UserFingerprint.t()),
          other_users: %{optional(String.t()) => [UserFingerprint.t()]}
        }
end
