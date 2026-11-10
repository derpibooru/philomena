defmodule Philomena.SourceChanges.SourceChangePage do
  @moduledoc """
  A paginated source-change history together with its resolved target metadata.

  `range` is present for masked IP histories, and `image_count` is present for
  user histories.
  """

  alias Philomena.Images.Image
  alias Philomena.Users.User

  @enforce_keys [:target, :source_changes]
  defstruct [:target, :source_changes, :range, :image_count]

  @type target :: Image.t() | User.t() | Postgrex.INET.t() | String.t()

  @type t :: %__MODULE__{
          target: target(),
          source_changes: Scrivener.Page.t(),
          range: Postgrex.INET.t() | nil,
          image_count: non_neg_integer() | nil
        }
end
