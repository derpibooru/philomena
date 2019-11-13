defmodule PhilomenaWeb.CommentController do
  use PhilomenaWeb, :controller

  alias Philomena.{Comments.Comment, Textile.Renderer}
  import Ecto.Query

  def index(conn, _params) do
    comments =
      Comment.search_records(
        %{
          query: %{
            bool: %{
              must: [
                %{range: %{posted_at: %{gt: "now-1w"}}},
                %{term: %{hidden_from_users: false}}
              ]
            }
          },
          sort: %{posted_at: :desc}
        },
        conn.assigns.pagination,
        Comment |> preload([:image, user: [awards: :badge]])
      )

    rendered =
      comments.entries
      |> Renderer.render_collection()

    comments =
      %{comments | entries: Enum.zip(comments.entries, rendered)}

    render(conn, "index.html", comments: comments)
  end
end
