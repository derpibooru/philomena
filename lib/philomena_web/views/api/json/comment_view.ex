defmodule PhilomenaWeb.Api.Json.CommentView do
  use PhilomenaWeb, :view
  alias PhilomenaWeb.UserAttributionView

  def render("index.json", %{comments: comments, total: total} = assigns) do
    %{
      comments: render_many(comments, PhilomenaWeb.Api.Json.CommentView, "comment.json", assigns),
      total: total
    }
  end

  def render("show.json", %{comment: comment} = assigns) do
    %{comment: render_one(comment, PhilomenaWeb.Api.Json.CommentView, "comment.json", assigns)}
  end

  def render("comment.json", %{comment: %{destroyed_content: true}}) do
    nil
  end

  def render("comment.json", %{comment: %{image: %{hidden_from_users: true}} = comment}) do
    %{
      id: comment.id,
      image_id: comment.image_id,
      user_id: nil,
      author: nil,
      body: nil,
      posted_at: nil,
      updated_at: nil
    }
  end

  def render("comment.json", %{comment: %{hidden_from_users: true} = comment}) do
    %{
      id: comment.id,
      image_id: comment.image_id,
      user_id: if(not comment.anonymous, do: comment.user_id),
      author:
        if(comment.anonymous or is_nil(comment.user),
          do: UserAttributionView.anonymous_name(comment),
          else: comment.user.name
        ),
      body: nil,
      posted_at: comment.created_at,
      updated_at: comment.updated_at
    }
  end

  def render("comment.json", %{comment: comment}) do
    %{
      id: comment.id,
      image_id: comment.image_id,
      user_id: if(not comment.anonymous, do: comment.user_id),
      author:
        if(comment.anonymous or is_nil(comment.user),
          do: UserAttributionView.anonymous_name(comment),
          else: comment.user.name
        ),
      body: comment.body,
      posted_at: comment.created_at,
      updated_at: comment.updated_at
    }
  end
end
