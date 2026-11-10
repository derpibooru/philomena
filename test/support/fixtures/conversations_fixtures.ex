defmodule Philomena.ConversationsFixtures do
  @moduledoc """
  Test-only conversation builders. They persist schemas directly because the
  production context intentionally exposes only actor-scoped request APIs.
  """

  alias Philomena.Conversations.Conversation
  alias Philomena.Conversations.Message
  alias Philomena.Multi
  alias Philomena.Repo
  alias Philomena.Reports

  def unique_conversation_title, do: "Test Conversation #{System.unique_integer([:positive])}"

  @doc """
  Creates a conversation from `from` to `to` with one initial message.

  `attrs` are merged into the string-keyed params map the way the
  conversation controller would submit them; pass
  `"messages" => %{"0" => %{"body" => ...}}` to override the message body.

  Returns the conversation with `messages: [first_message]` loaded.
  """
  def conversation_fixture(from, to, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        "recipient" => to.name,
        "title" => unique_conversation_title(),
        "messages" => %{"0" => %{"body" => "Test message body"}}
      })

    conversation =
      %Conversation{recipient: to.name}
      |> Conversation.creation_changeset(from, to, attrs)
      |> Repo.insert!()

    report_non_approved_message(List.first(conversation.messages))

    conversation
  end

  @doc """
  Creates a reply message in `conversation` from `user`.
  """
  def message_fixture(conversation, user, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{"body" => "Test reply body"})

    {:ok, message} =
      Repo.transaction(fn ->
        message =
          conversation
          |> Ecto.build_assoc(:messages)
          |> Message.creation_changeset(attrs, user)
          |> Repo.insert!()

        conversation
        |> Conversation.new_message_changeset()
        |> Repo.update!()

        message
      end)

    report_non_approved_message(message)

    message
  end

  defp report_non_approved_message(nil), do: :ok
  defp report_non_approved_message(%Message{approved: true}), do: :ok

  defp report_non_approved_message(%Message{} = message) do
    Multi.new()
    |> Reports.put_create_system_report(
      "Approval",
      "PM contains externally-embedded images",
      :conversation_id,
      message.conversation_id
    )
    |> Multi.transact()

    :ok
  end
end
