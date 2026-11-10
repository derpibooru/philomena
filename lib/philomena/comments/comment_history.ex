defmodule Philomena.Comments.CommentHistory do
  @moduledoc """
  An image's comment and the versions displayed on its history page.
  """

  alias Philomena.Comments.{Comment, CommentVersion}
  alias Philomena.Images.Image

  @enforce_keys [:image, :comment, :versions]
  defstruct [:image, :comment, versions: []]

  @type t :: %__MODULE__{
          image: Image.t(),
          comment: Comment.t(),
          versions: [CommentVersion.t()]
        }
end
