defmodule Philomena.Forums.ForumIndex do
  @moduledoc """
  Actor-visible forums and the number of topics visible within them.
  """

  alias Philomena.Forums.Forum

  @enforce_keys [:forums, :topic_count]
  defstruct @enforce_keys

  @type t :: %__MODULE__{forums: Scrivener.Page.t(Forum.t()), topic_count: non_neg_integer()}
end
