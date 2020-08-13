defmodule PhilomenaWeb.Api.Json.Forum.TopicView do
  use PhilomenaWeb, :view
  alias PhilomenaWeb.UserAttributionView

  def render("index.json", %{topics: topics, total: total} = assigns) do
    %{
      topics: render_many(topics, PhilomenaWeb.Api.Json.Forum.TopicView, "topic.json", assigns),
      total: total
    }
  end

  def render("show.json", %{topic: topic} = assigns) do
    %{topic: render_one(topic, PhilomenaWeb.Api.Json.Forum.TopicView, "topic.json", assigns)}
  end

  def render("topic.json", %{topic: %{hidden_from_users: true}}) do
    %{
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

  def render("topic.json", %{topic: topic}) do
    %{
      slug: topic.slug,
      title: topic.title,
      post_count: topic.post_count,
      view_count: topic.view_count,
      sticky: topic.sticky,
      last_replied_to_at: topic.last_replied_to_at,
      locked: not is_nil(topic.locked_at),
      user_id: if(not topic.anonymous, do: topic.user_id),
      author:
        if(topic.anonymous or is_nil(topic.user),
          do: UserAttributionView.anonymous_name(topic),
          else: topic.user.name
        )
    }
  end
end
