defmodule Philomena.Topics.TopicPage do
  @moduledoc """
  Assembled state for a single forum topic: the forum and topic being viewed,
  the current page of posts, the viewer's subscription and poll-vote state,
  whether the topic's poll is currently accepting votes, and the two changesets
  for replying and for editing the title.

  `posts` is a `Scrivener.Page` whose entries are raw `Post` structs; this struct
  never carries rendered Markdown.
  """

  alias Philomena.Forums.Forum
  alias Philomena.Topics.Topic

  @enforce_keys [
    :forum,
    :topic,
    :posts,
    :watching,
    :voted,
    :poll_active,
    :post_changeset,
    :topic_changeset
  ]

  defstruct @enforce_keys

  @type t :: %__MODULE__{
          forum: Forum.t(),
          topic: Topic.t(),
          posts: Scrivener.Page.t(),
          watching: boolean(),
          voted: boolean(),
          poll_active: boolean(),
          post_changeset: Ecto.Changeset.t(),
          topic_changeset: Ecto.Changeset.t()
        }
end
