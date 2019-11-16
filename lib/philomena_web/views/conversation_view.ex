defmodule PhilomenaWeb.ConversationView do
  use PhilomenaWeb, :view

  def other_party(user_id, %{to_id: user_id} = conversation),
    do: conversation.from

  def other_party(_user_id, conversation),
    do: conversation.to
end