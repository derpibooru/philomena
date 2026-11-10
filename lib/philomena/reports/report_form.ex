defmodule Philomena.Reports.ReportForm do
  @moduledoc """
  A report form paired with the safely loaded target it reports and the
  reportable rules available for selection.

  The target is retained when validation fails so the controller can render the
  same form without loading or authorizing the resource a second time. Rules
  are loaded before presentation so views never query while rendering.
  """

  alias Philomena.Comments.Comment
  alias Philomena.Commissions.Commission
  alias Philomena.Conversations.Conversation
  alias Philomena.Galleries.Gallery
  alias Philomena.Images.Image
  alias Philomena.Posts.Post
  alias Philomena.Rules.Rule
  alias Philomena.Users.User

  @type target ::
          Image.t()
          | Comment.t()
          | Post.t()
          | User.t()
          | Commission.t()
          | Conversation.t()
          | Gallery.t()

  @enforce_keys [:target, :changeset, :rules]
  defstruct [:target, :changeset, :rules]

  @type t :: %__MODULE__{
          target: target(),
          changeset: Ecto.Changeset.t(),
          rules: [Rule.t()]
        }
end
