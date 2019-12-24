defmodule PhilomenaWeb.PostJson do
  alias PhilomenaWeb.UserAttributionView

  def as_json(post) do
    %{
      id: post.id,
      topic_id: post.topic_id,
      user_id: if(not post.anonymous, do: post.user_id),
      author: if(post.anonymous or is_nil(post.user), do: UserAttributionView.anonymous_name(post), else: post.user.name),
      body: if(not post.topic.hidden_from_users and not post.hidden_from_users, do: post.body)
    }
  end
end