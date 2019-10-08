defmodule PhilomenaWeb.SearchController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.{Image, Query}
  alias Pow.Plug

  import Ecto.Query

  def index(conn, params) do
    filter = conn.assigns[:compiled_filter]
    user = conn |> Plug.current_user()

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

      conn
      |> render("index.html", images: images, search_query: params["q"])
    else
      {:error, _msg} ->
        conn
        |> render("index.html",
          images: [],
          search_query: params["q"]
        )
    end
  end
end
