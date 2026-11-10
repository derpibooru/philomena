defmodule Philomena.Conversations.ConversationIndex do
  @moduledoc """
  A conversation index result containing paginated conversations and the
  partner filter changeset.
  """

  alias Philomena.Conversations.Conversation

  @enforce_keys [:conversations, :changeset]
  defstruct [:conversations, :changeset]

  @type t :: %__MODULE__{
          conversations: Scrivener.Page.t(Conversation.t()),
          changeset: Ecto.Changeset.t()
        }
end
