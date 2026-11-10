defmodule Philomena.TagChanges.TagChangePage do
  @moduledoc """
  A paginated tag-change listing and its independently resolved target.

  `target` is `nil` for the global listing. Resource-specific listings carry the
  loaded image, tag, user, canonical IP address, or canonical fingerprint.
  """

  alias Philomena.Images.Image
  alias Philomena.Tags.Tag
  alias Philomena.Users.User

  @type target :: Image.t() | Tag.t() | User.t() | Postgrex.INET.t() | String.t() | nil

  @enforce_keys [:target, :tag_changes]
  defstruct [:target, :tag_changes]

  @type t :: %__MODULE__{
          target: target(),
          tag_changes: Scrivener.Page.t()
        }
end
