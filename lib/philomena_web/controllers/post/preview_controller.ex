defmodule PhilomenaWeb.Post.PreviewController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.Posts.Post
  alias Philomena.Users

  def create(conn, params) do
    user = Users.preload_preview_awards(conn.assigns.current_user)
    body = to_string(params["body"])
    anonymous = params["anonymous"] == true

    post = %Post{user: user, body: body, anonymous: anonymous}
    rendered = MarkdownRenderer.render_one(post, conn)

    render(conn, "create.html", layout: false, post: post, body: rendered)
  end
end
