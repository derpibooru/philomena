defmodule PhilomenaWeb.Post.PreviewController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.TextRenderer
  alias Philomena.Posts.Post
  alias Philomena.Repo

  def create(conn, params) do
    user = preload_awards(conn.assigns.current_user)
    body = to_string(params["body"])
    anonymous = params["anonymous"] == true

    post = %Post{user: user, body: body, anonymous: anonymous}
    rendered = TextRenderer.render_one(post, conn)

    render(conn, "create.html", layout: false, post: post, body: rendered)
  end

  defp preload_awards(nil), do: nil

  defp preload_awards(user) do
    Repo.preload(user, awards: :badge)
  end
end
