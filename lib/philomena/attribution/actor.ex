defmodule Philomena.Attribution.Actor do
  @moduledoc """
  The typed actor/attribution passed to context functions.

  Context functions that act on behalf of someone take the actor first.

  Where that actor is really an *attribution* (a user together with the IP and
  fingerprint attributing an action - e.g. image uploads, tag changes, posts),
  this struct holds all relevant data for authorization and persistence.
  """

  alias Philomena.Users.User

  @enforce_keys [:ip]
  defstruct user: nil, ip: nil, fingerprint: nil, ban: nil

  @type t :: %__MODULE__{
          user: User.t() | nil,
          ip: EctoNetwork.INET.t(),
          fingerprint: String.t() | nil,
          ban: map() | nil
        }

  @doc """
  Converts an `Actor` to a map of changes suitable for passing as the second argument
  to `Ecto.Changeset.change/2`.

  ## Examples

      iex> to_changes(actor)
      %{fingerprint: "abcdef", ip: %Postgrex.INET{}, user: %User{}}

  """
  @spec to_changes(t()) :: %{
          fingerprint: String.t() | nil,
          ip: EctoNetwork.INET.t(),
          user: User.t() | nil
        }
  def to_changes(%__MODULE__{fingerprint: fingerprint, ip: ip, user: user}) do
    %{fingerprint: fingerprint, ip: ip, user: user}
  end
end
