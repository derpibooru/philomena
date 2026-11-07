defmodule PhilomenaWeb.ConversationController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.NotificationCountPlug
  alias PhilomenaWeb.RateLimitedResponse
  alias Philomena.Conversations
  alias Philomena.Conversations.ConversationIndex
  alias PhilomenaWeb.MarkdownRenderer

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    with {:ok, %ConversationIndex{} = index} <-
           Conversations.list_conversations(
             conn.assigns.actor,
             params,
             conn.assigns.scrivener
           ) do
      render(conn, "index.html",
        title: "Conversations",
        conversations: index.conversations,
        changeset: index.changeset
      )
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, page} <-
           Conversations.show_conversation(
             conn.assigns.actor,
             id,
             conn.assigns.scrivener
           ) do
      # The page load marked the conversation read; refresh the header
      # notification ticker afterwards so it reflects the cleared state.
      conn = NotificationCountPlug.call(conn)

      rendered = MarkdownRenderer.render_collection(page.messages.entries, conn)
      messages = %{page.messages | entries: Enum.zip(page.messages.entries, rendered)}

      render(conn, "show.html",
        title: "Showing Conversation",
        conversation: page.conversation,
        messages: messages,
        changeset: page.changeset,
        trusted?: Conversations.trusted_sender?(conn.assigns.actor)
      )
    end
  end

  def new(conn, params) do
    with {:ok, changeset} <- Conversations.new_conversation(conn.assigns.actor, params) do
      render(conn, "new.html",
        title: "New Conversation",
        changeset: changeset,
        trusted?: Conversations.trusted_sender?(conn.assigns.actor)
      )
    end
  end

  def create(conn, params) do
    case Conversations.create_conversation(conn.assigns.actor, params["conversation"] || %{}) do
      {:ok, conversation} ->
        conn
        |> put_flash(:info, "Conversation successfully created.")
        |> redirect(to: ~p"/conversations/#{conversation}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html",
          changeset: changeset,
          trusted?: Conversations.trusted_sender?(conn.assigns.actor)
        )

      {:error, :rate_limited} ->
        RateLimitedResponse.call(conn, "You may only create a conversation once every minute.")

      error ->
        error
    end
  end
end
