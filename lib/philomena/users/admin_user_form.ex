defmodule Philomena.Users.AdminUserForm do
  @moduledoc """
  A staff-managed user changeset and assignable roles.
  """

  alias Philomena.Roles.Role
  @enforce_keys [:changeset, :roles]
  defstruct [:changeset, :roles]

  @type t :: %__MODULE__{
          changeset: Ecto.Changeset.t(),
          roles: [Role.t()]
        }
end
