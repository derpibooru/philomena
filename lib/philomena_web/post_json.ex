defmodule PhilomenaWeb.PostJson do
  alias PhilomenaWeb.UserAttributionView

  def as_json(%{topic: %{hidden_from_users: true}} = post) do
    %{
      id: post.id,
      topic_id: post.topic_id,
      user_id: nil,
      author: nil,
      body: nil
    }
  end

  def as_json(%{hidden_from_users: true} = post) do
    %{
      id: post.id,
      topic_id: post.topic_id,
      user_id: if(not post.anonymous, do: post.user_id),
      author: if(post.anonymous or is_nil(post.user), do: UserAttributionView.anonymous_name(post), else: post.user.name),
      body: nil
    }
  end

  def as_json(post) do
    %{
      id: post.id,
      topic_id: post.topic_id,
      user_id: if(not post.anonymous, do: post.user_id),
      author: if(post.anonymous or is_nil(post.user), do: UserAttributionView.anonymous_name(post), else: post.user.name),
      body: post.body
    }
  end

end
