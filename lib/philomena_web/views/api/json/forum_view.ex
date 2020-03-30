defmodule PhilomenaWeb.Api.Json.ForumView do
  use PhilomenaWeb, :view

  def render("index.json", %{forums: forums, total: total} = assigns) do
    %{
      forums: render_many(forums, PhilomenaWeb.Api.Json.ForumView, "forum.json", assigns),
      total: total
    }
  end

  def render("show.json", %{forum: forum} = assigns) do
    %{forum: render_one(forum, PhilomenaWeb.Api.Json.ForumView, "forum.json", assigns)}
  end

  def render("forum.json", %{forum: %{access_level: "normal"} = forum}) do
    %{
      name: forum.name,
      short_name: forum.short_name,
      description: forum.description,
      topic_count: forum.topic_count,
      post_count: forum.post_count
    }
  end

  def render("forum.json", _assigns) do
    %{
      name: nil,
      short_name: nil,
      description: nil,
      topic_count: nil,
      post_count: nil
    }
  end
end
