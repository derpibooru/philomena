defmodule PhilomenaWeb.SearchController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.{Image, Query}
  alias Philomena.Interactions

  import Ecto.Query

  def index(conn, params) do
    filter = conn.assigns.compiled_filter
    user = conn.assigns.current_user

    with {:ok, query} <- Query.compile(user, params["q"]) do
      images =
        Image.search_records(
          %{
            query: %{bool: %{must: query, must_not: [filter, %{term: %{hidden_from_users: true}}]}},
            sort: %{created_at: :desc}
          },
          conn.assigns.pagination,
          Image |> preload(:tags)
        )

      interactions =
        Interactions.user_interactions(images, user)

      conn
      |> render("index.html", images: images, search_query: params["q"], interactions: interactions)
    else
      {:error, msg} ->
        conn
        |> render("index.html",
          images: [],
          error: msg,
          search_query: params["q"]
        )
    end
  end
end
