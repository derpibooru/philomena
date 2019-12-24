defmodule PhilomenaWeb.CommentJson do
  alias PhilomenaWeb.UserAttributionView

  def as_json(comment) do
    %{
      id: comment.id,
      image_id: comment.image_id,
      user_id: if(not comment.anonymous, do: comment.user_id),
      author: if(comment.anonymous or is_nil(comment.user), do: UserAttributionView.anonymous_name(comment), else: comment.user.name),
      body: if(not comment.image.hidden_from_users and not comment.hidden_from_users, do: comment.body)
    }
  end
end