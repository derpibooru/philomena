defmodule Philomena.Conversations.ConversationPage do
  @moduledoc """
  Assembled data for the conversation page: the conversation, a
  `m:Scrivener.Page` of its messages, and a changeset for a reply.

  Message bodies are carried unrendered.
  """

  alias Philomena.Conversations.Conversation

  @enforce_keys [:conversation, :messages, :changeset]
  defstruct [:conversation, :messages, :changeset]

  @type t :: %__MODULE__{
          conversation: Conversation.t(),
          messages: Scrivener.Page.t(),
          changeset: Ecto.Changeset.t()
        }
end
