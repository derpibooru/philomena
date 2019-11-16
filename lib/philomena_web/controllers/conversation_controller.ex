defmodule PhilomenaWeb.ConversationController do
  use PhilomenaWeb, :controller

  alias Philomena.Conversations.{Conversation, Message}
  alias Philomena.Textile.Renderer
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.Plugs.FilterBannedUsers when action in [:new, :create]
  plug :load_and_authorize_resource, model: Conversation, id_field: "slug", only: :show

  def index(conn, _params) do
    user = conn.assigns.current_user

    conversations =
      Conversation
      |> where([c], (c.from_id == ^user.id and not c.from_hidden) or (c.to_id == ^user.id and not c.to_hidden))
      |> order_by(desc: :last_message_at)
      |> preload([:to, :from])
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html", conversations: conversations)
  end

  def show(conn, _params) do
    conversation = conn.assigns.conversation

    messages =
      Message
      |> where(conversation_id: ^conversation.id)
      |> order_by(asc: :created_at)
      |> preload([:from])
      |> Repo.paginate(conn.assigns.scrivener)

    rendered =
      messages.entries
      |> Renderer.render_collection()

    messages =
      %{messages | entries: Enum.zip(messages.entries, rendered)}

    render(conn, "show.html", conversation: conversation, messages: messages)
  end
end