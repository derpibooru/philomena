defmodule PhilomenaWeb.Api.Json.Search.PostController do
  use PhilomenaWeb, :controller

  alias Philomena.Elasticsearch
  alias Philomena.Posts.Post
  alias Philomena.Posts.Query
  import Ecto.Query

  def index(conn, params) do
    user = conn.assigns.current_user

    case Query.compile(user, params["q"] || "") do
      {:ok, query} ->
        posts =
          Post
          |> Elasticsearch.search_definition(
            %{
              query: %{
                bool: %{
                  must: [
                    query,
                    %{term: %{deleted: false}},
                    %{term: %{access_level: "normal"}}
                  ]
                }
              },
              sort: %{created_at: :desc}
            },
            conn.assigns.pagination
          )
          |> Elasticsearch.search_records(preload(Post, [:user, :topic]))

        conn
        |> put_view(PhilomenaWeb.Api.Json.Forum.Topic.PostView)
        |> render("index.json", posts: posts, total: posts.total_entries)

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end
