defmodule Philomena.Commissions.Directory do
  @moduledoc """
  Commission directory page: the paginated listings, search form
  changeset, and current viewer with their commission preloaded when signed in.
  """

  alias Philomena.Commissions.Commission
  alias Philomena.Users.User

  @enforce_keys [:commissions, :changeset, :current_user]
  defstruct [:commissions, :changeset, :current_user]

  @type t :: %__MODULE__{
          commissions: Scrivener.Page.t(Commission.t()) | nil,
          changeset: Ecto.Changeset.t(),
          current_user: User.t() | nil
        }
end
