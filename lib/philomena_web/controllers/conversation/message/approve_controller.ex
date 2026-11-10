defmodule PhilomenaWeb.Conversation.Message.ApproveController do
  use PhilomenaWeb, :controller

  alias Philomena.Conversations

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"conversation_id" => conversation_id, "message_id" => message_id}) do
    case Conversations.create_message_approve(conn.assigns.actor, conversation_id, message_id) do
      {:ok, _message} ->
        conn
        |> put_flash(:info, "Conversation message approved.")
        |> redirect(to: "/")

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:info, "Conversation message has already been approved.")
        |> redirect(to: "/")

      error ->
        error
    end
  end
end
