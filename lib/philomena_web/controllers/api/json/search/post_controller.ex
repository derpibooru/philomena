defmodule PhilomenaWeb.Api.Json.Search.PostController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.PostJson
  alias Philomena.Posts.Post
  alias Philomena.Posts.Query
  import Ecto.Query

  def index(conn, params) do
    user = conn.assigns.current_user

    case Query.compile(user, params["q"] || "") do
      {:ok, query} ->
        posts =
          Post.search_records(
            %{
              query: %{
                bool: %{
                  must: [
                    query,
                    %{term: %{deleted: false}},
                    %{term: %{access_level: "normal"}}
                  ],
                }
              },
              sort: %{created_at: :desc}
            },
            conn.assigns.pagination,
            preload(Post, [:user, :topic])
          )

        json(conn, %{posts: Enum.map(posts, &PostJson.as_json/1)})

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end