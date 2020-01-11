defmodule PhilomenaWeb.CommentJson do
  alias PhilomenaWeb.UserAttributionView

  def as_json(%{destroyed_content: true}) do
    nil
  end

  def as_json(%{image: %{hidden_from_users: true}} = comment) do
    %{
      id: comment.id,
      image_id: comment.image_id,
      user_id: nil,
      author: nil,
      body: nil
    }
  end

  def as_json(%{hidden_from_users: true} = comment) do
    %{
      id: comment.id,
      image_id: comment.image_id,
      user_id: if(not comment.anonymous, do: comment.user_id),
      author:
        if(comment.anonymous or is_nil(comment.user),
          do: UserAttributionView.anonymous_name(comment),
          else: comment.user.name
        ),
      body: nil
    }
  end

  def as_json(comment) do
    %{
      id: comment.id,
      image_id: comment.image_id,
      user_id: if(not comment.anonymous, do: comment.user_id),
      author:
        if(comment.anonymous or is_nil(comment.user),
          do: UserAttributionView.anonymous_name(comment),
          else: comment.user.name
        ),
      body: comment.body
    }
  end
end
