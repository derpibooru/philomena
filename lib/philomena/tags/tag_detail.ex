defmodule Philomena.Tags.TagDetail do
  @moduledoc """
  Staff-facing usage metadata for one resolved tag.
  """

  alias Philomena.Filters.Filter
  alias Philomena.Tags.Tag
  alias Philomena.Users.User

  @enforce_keys [:tag, :filters_spoilering, :filters_hiding, :users_watching]
  defstruct [:tag, :filters_spoilering, :filters_hiding, :users_watching]

  @type t :: %__MODULE__{
          tag: Tag.t(),
          filters_spoilering: [Filter.t()],
          filters_hiding: [Filter.t()],
          users_watching: [User.t()]
        }
end
