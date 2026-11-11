defmodule Philomena.TagChanges.TagChangePage do
  @moduledoc """
  A paginated tag-change listing and its independently resolved target.

  `target` is `nil` for the global listing. Resource-specific listings carry the
  loaded image, tag, user, canonical IP address, or canonical fingerprint.

  `added_query` and `removed_query` are `tcq` search strings narrowing the
  listing to additions or removals: of the target tag on a tag listing, of any
  tag elsewhere.
  """

  alias Philomena.Images.Image
  alias Philomena.Tags.Tag
  alias Philomena.Users.User

  @type target :: Image.t() | Tag.t() | User.t() | Postgrex.INET.t() | String.t() | nil

  @enforce_keys [:target, :tag_changes, :added_query, :removed_query]
  defstruct [:target, :tag_changes, :added_query, :removed_query]

  @type t :: %__MODULE__{
          target: target(),
          tag_changes: Scrivener.Page.t(),
          added_query: String.t(),
          removed_query: String.t()
        }
end
