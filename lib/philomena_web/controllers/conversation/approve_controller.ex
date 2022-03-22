defmodule PhilomenaWeb.Conversation.ApproveController do
  use PhilomenaWeb, :controller

  alias Philomena.Conversations.Conversation
  alias Philomena.Conversations

  plug PhilomenaWeb.CanaryMapPlug, create: :approve

  plug :load_and_authorize_resource,
    model: Conversation,
    id_field: "slug",
    id_name: "conversation_id",
    persisted: true

  def create(conn, _params) do
    message = conn.assigns.message
    user = conn.assigns.current_user

    {:ok, _message} = Conversations.approve_conversation_message(message)

    conn
    |> put_flash(:info, "Conversation message approved.")
    |> moderation_log(details: &log_details/3, data: message)
    |> redirect(to: "/")
  end

  defp log_details(conn, _action, message) do
    %{
      body: "Approved private message in conversation ##{message.conversation_id}",
      subject_path: "/"
    }
  end
end
