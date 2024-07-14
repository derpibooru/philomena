defmodule PhilomenaWeb.Conversation.MessageController do
  use PhilomenaWeb, :controller

  alias Philomena.Conversations.Conversation
  alias Philomena.Conversations

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.CanaryMapPlug, create: :show

  plug :load_and_authorize_resource,
    model: Conversation,
    id_name: "conversation_id",
    id_field: "slug",
    persisted: true

  @page_size 25

  def create(conn, %{"message" => message_params}) do
    conversation = conn.assigns.conversation
    user = conn.assigns.current_user

    case Conversations.create_message(conversation, user, message_params) do
      {:ok, _message} ->
        count = Conversations.count_messages(conversation)
        page = div(count + @page_size - 1, @page_size)

        conn
        |> put_flash(:info, "Message successfully sent.")
        |> redirect(to: ~p"/conversations/#{conversation}?#{[page: page]}")

      _error ->
        conn
        |> put_flash(:error, "There was an error posting your message")
        |> redirect(to: ~p"/conversations/#{conversation}")
    end
  end
end
