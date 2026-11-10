defmodule Philomena.Activities.FrontPage do
  @moduledoc """
  The assembled homepage: the recent-image listing, the top-scoring strip, the
  recent-comment strip, the viewer's watched images (`nil` for anonymous
  visitors), the current featured image, the live-stream and forum-topic
  strips, and the viewer's interactions across the image collections.
  """

  alias Philomena.Channels.Channel
  alias Philomena.Comments.Comment
  alias Philomena.Images.Image
  alias Philomena.Topics.Topic

  @enforce_keys [
    :images,
    :top_scoring,
    :comments,
    :watched,
    :featured_image,
    :streams,
    :topics,
    :interactions
  ]
  defstruct images: nil,
            top_scoring: nil,
            comments: nil,
            watched: nil,
            featured_image: nil,
            streams: [],
            topics: [],
            interactions: []

  @type t :: %__MODULE__{
          images: Scrivener.Page.t(Image.t()),
          top_scoring: Scrivener.Page.t(Image.t()),
          comments: Scrivener.Page.t(Comment.t()),
          watched: Scrivener.Page.t(Image.t()) | nil,
          featured_image: Image.t() | nil,
          streams: [Channel.t()],
          topics: [Topic.t()],
          interactions: list()
        }
end
