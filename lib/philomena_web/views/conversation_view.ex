defmodule PhilomenaWeb.ConversationView do
  use PhilomenaWeb, :view

  def other_party(%{id: user_id}, %{to_id: user_id} = conversation),
    do: conversation.from

  def other_party(_user, conversation),
    do: conversation.to

  def read_by?(%{id: user_id}, %{to_id: user_id} = conversation),
    do: conversation.to_read

  def read_by?(%{id: user_id}, %{from_id: user_id} = conversation),
    do: conversation.from_read

  def read_by?(_user, _conversation),
    do: false

  def conversation_class(user, conversation) do
    case read_by?(user, conversation) do
      false -> "warning"
      _ -> nil
    end
  end

  def last_message_path(conn, conversation, count) do
    page = trunc(Float.ceil(count / 25))

    Routes.conversation_path(conn, :show, conversation, page: page)
  end
end
