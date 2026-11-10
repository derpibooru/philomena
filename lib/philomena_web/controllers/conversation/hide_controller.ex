defmodule PhilomenaWeb.Conversation.HideController do
  use PhilomenaWeb, :controller

  alias Philomena.Conversations

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"conversation_id" => conversation_id}) do
    with {:ok, _conversation} <-
           Conversations.update_conversation_hide(conn.assigns.actor, conversation_id) do
      conn
      |> put_flash(:info, "Conversation hidden.")
      |> redirect(to: ~p"/conversations")
    end
  end

  def delete(conn, %{"conversation_id" => conversation_id}) do
    with {:ok, conversation} <-
           Conversations.update_conversation_hide(
             conn.assigns.actor,
             conversation_id,
             false
           ) do
      conn
      |> put_flash(:info, "Conversation restored.")
      |> redirect(to: ~p"/conversations/#{conversation}")
    end
  end
end
