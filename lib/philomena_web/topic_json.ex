defmodule PhilomenaWeb.TopicJson do
  alias PhilomenaWeb.UserAttributionView

  def as_json(%{hidden_from_users: true} = topic) do
    %{
      id: topic.id,
      slug: nil,
      title: nil,
      post_count: nil,
      view_count: nil,
      sticky: nil,
      last_replied_to_at: nil,
      locked: nil,
      user_id: nil,
      author: nil
    }
  end

  def as_json(topic) do
    %{
      id: topic.id,
      slug: topic.slug,
      title: topic.title,
      post_count: topic.post_count,
      view_count: topic.view_count,
      sticky: topic.sticky,
      last_replied_to_at: topic.last_replied_to_at,
      forum_id: topic.forum_id,
      locked: if(is_nil(topic.locked_at), do: :false, else: :true),
      user_id: if(not topic.anonymous, do: topic.user.id),
      author: if(topic.anonymous or is_nil(topic.user), do: UserAttributionView.anonymous_name(topic), else: topic.user.name)
    }
  end
end
