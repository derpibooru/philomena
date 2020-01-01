defmodule PhilomenaWeb.ForumJson do

  def as_json(%{access_level: "normal"} = forum) do
    %{
      id: forum.id,
      name: forum.name,
      short_name: forum.short_name,
      description: forum.description,
      topic_count: forum.topic_count,
      post_count: forum.post_count
    }
  end

  def as_json(forum) do
    %{
      id: forum.id,
      name: nil,
      short_name: nil,
      description: nil,
      topic_count: nil,
      post_count: nil
    }
  end
end
