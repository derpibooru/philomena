defmodule Philomena.Forums.ForumPage do
  @moduledoc """
  A forum, its paginated visible topics, and the viewer's subscription state.
  """

  alias Philomena.Forums.Forum
  alias Philomena.Topics.Topic

  @enforce_keys [:forum, :topics, :watching]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          forum: Forum.t(),
          topics: Scrivener.Page.t(Topic.t()),
          watching: boolean()
        }
end
