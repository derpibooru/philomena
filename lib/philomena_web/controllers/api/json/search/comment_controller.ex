defmodule PhilomenaWeb.Api.Json.Search.CommentController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.CommentJson
  alias Philomena.Elasticsearch
  alias Philomena.Comments.Comment
  alias Philomena.Comments.Query
  import Ecto.Query

  def index(conn, params) do
    user = conn.assigns.current_user
    filter = conn.assigns.current_filter

    case Query.compile(user, params["q"] || "") do
      {:ok, query} ->
        comments =
          Elasticsearch.search_records(
            Comment,
            %{
              query: %{
                bool: %{
                  must: [
                    query,
                    %{term: %{hidden_from_users: false}}
                  ],
                  must_not: %{
                    terms: %{image_tag_ids: filter.hidden_tag_ids}
                  }
                }
              },
              sort: %{posted_at: :desc}
            },
            conn.assigns.pagination,
            preload(Comment, [:image, :user])
          )

        json(conn, %{comments: Enum.map(comments, &CommentJson.as_json/1)})

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end
