defmodule PhilomenaWeb.Api.Json.Forum.Topic.PostView do
  use PhilomenaWeb, :view
  alias PhilomenaWeb.UserAttributionView

  def render("index.json", %{posts: posts, total: total} = assigns) do
    %{
      posts: render_many(posts, PhilomenaWeb.Api.Json.Forum.Topic.PostView, "post.json", assigns),
      total: total
    }
  end

  def render("show.json", %{post: post} = assigns) do
    %{post: render_one(post, PhilomenaWeb.Api.Json.Forum.Topic.PostView, "post.json", assigns)}
  end

  def render("post.json", %{post: %{topic: %{hidden_from_users: true}} = post}) do
    %{
      id: post.id,
      user_id: nil,
      author: nil,
      body: nil,
      created_at: nil,
      updated_at: nil,
      edited_at: nil,
      edit_reason: nil
    }
  end

  def render("post.json", %{post: %{hidden_from_users: true} = post}) do
    %{
      id: post.id,
      user_id: if(not post.anonymous, do: post.user_id),
      author:
        if(post.anonymous or is_nil(post.user),
          do: UserAttributionView.anonymous_name(post),
          else: post.user.name
        ),
      body: nil,
      created_at: post.created_at,
      updated_at: post.updated_at,
      edited_at: nil,
      edit_reason: nil
    }
  end

  def render("post.json", %{post: post}) do
    %{
      id: post.id,
      user_id: if(not post.anonymous, do: post.user_id),
      author:
        if(post.anonymous or is_nil(post.user),
          do: UserAttributionView.anonymous_name(post),
          else: post.user.name
        ),
      body: post.body,
      created_at: post.created_at,
      updated_at: post.updated_at,
      edited_at: post.edited_at,
      edit_reason: post.edit_reason
    }
  end
end
