defmodule Philomena.Users.AliasMatches do
  @moduledoc """
  A user and potential aliases grouped by shared IP, fingerprint, or both.
  """

  alias Philomena.Users.User

  @enforce_keys [:user, :both_matches, :ip_matches, :fp_matches]
  defstruct [:user, :both_matches, :ip_matches, :fp_matches]

  @type t :: %__MODULE__{
          user: User.t(),
          both_matches: [User.t()],
          ip_matches: [User.t()],
          fp_matches: [User.t()]
        }
end
