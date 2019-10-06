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
            query: %{bool: %{must: query, must_not: filter}},
            sort: %{created_at: :desc}
          },
          Image |> preload(:tags)
        )

      conn
      |> put_view(PhilomenaWeb.ImageView)
      |> render("index.html", images: images, search_query: params["q"])
    else
      {:error, msg} ->
        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("index.html",
          images: [],
          error: msg,
          search_query: params["q"]
        )
    end
  end
end
