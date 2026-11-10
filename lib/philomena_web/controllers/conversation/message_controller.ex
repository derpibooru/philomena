defmodule PhilomenaWeb.Conversation.MessageController do
  use PhilomenaWeb, :controller

  alias Philomena.Conversations
  alias PhilomenaWeb.ConversationView
  alias PhilomenaWeb.MarkdownRenderer

  action_fallback PhilomenaWeb.FallbackController

  @page_size 25

  def create(conn, %{"conversation_id" => conversation_id} = params) do
    case Conversations.create_message(
           conn.assigns.actor,
           conversation_id,
           params["message"] || %{}
         ) do
      {:ok, %{conversation: conversation}} ->
        page = div(conversation.message_count + @page_size - 1, @page_size)

        conn
        |> put_flash(:info, "Message successfully sent.")
        |> redirect(to: ~p"/conversations/#{conversation}?#{[page: page]}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render_message_error(conn, conversation_id, changeset)

      error ->
        error
    end
  end

  defp render_message_error(conn, conversation_id, changeset) do
    with {:ok, page} <-
           Conversations.show_conversation(
             conn.assigns.actor,
             conversation_id,
             conn.assigns.scrivener
           ) do
      rendered = MarkdownRenderer.render_collection(page.messages.entries, conn)
      messages = %{page.messages | entries: Enum.zip(page.messages.entries, rendered)}

      conn
      |> put_view(ConversationView)
      |> render("show.html",
        title: "Showing Conversation",
        conversation: page.conversation,
        messages: messages,
        changeset: changeset,
        trusted?: Conversations.trusted_sender?(conn.assigns.actor)
      )
    end
  end
end
