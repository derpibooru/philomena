defmodule PhilomenaWeb.ConversationController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.NotificationCountPlug
  alias Philomena.{Conversations, Conversations.Conversation, Conversations.Message}
  alias PhilomenaWeb.MarkdownRenderer

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create]

  plug PhilomenaWeb.LimitPlug,
       [time: 60, error: "You may only create a conversation once every minute."]
       when action in [:create]

  plug :load_and_authorize_resource,
    model: Conversation,
    id_field: "slug",
    only: :show,
    preload: [:to, :from]

  def index(conn, params) do
    user = conn.assigns.current_user

    conversations =
      case params do
        %{"with" => partner_id} ->
          Conversations.list_conversations_with(partner_id, user, conn.assigns.scrivener)

        _ ->
          Conversations.list_conversations(user, conn.assigns.scrivener)
      end

    render(conn, "index.html", title: "Conversations", conversations: conversations)
  end

  def show(conn, _params) do
    conversation = conn.assigns.conversation
    user = conn.assigns.current_user

    messages =
      Conversations.list_messages(
        conversation,
        user,
        &MarkdownRenderer.render_collection(&1, conn),
        conn.assigns.scrivener
      )

    changeset = Conversations.change_message(%Message{})
    Conversations.mark_conversation_read(conversation, user)

    # Update the conversation ticker in the header
    conn = NotificationCountPlug.call(conn)

    render(conn, "show.html",
      title: "Showing Conversation",
      conversation: conversation,
      messages: messages,
      changeset: changeset
    )
  end

  def new(conn, params) do
    conversation =
      %Conversation{recipient: params["recipient"], messages: [%Message{}]}

    changeset = Conversations.change_conversation(conversation)

    render(conn, "new.html", title: "New Conversation", changeset: changeset)
  end

  def create(conn, %{"conversation" => conversation_params}) do
    user = conn.assigns.current_user

    case Conversations.create_conversation(user, conversation_params) do
      {:ok, conversation} ->
        conn
        |> put_flash(:info, "Conversation successfully created.")
        |> redirect(to: ~p"/conversations/#{conversation}")

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
