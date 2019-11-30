defmodule PhilomenaWeb.Api.WatchedController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.{Image, Query}
  import Ecto.Query

  def index(conn, _params) do
    user = conn.assigns.current_user
    filter = conn.assigns.compiled_filter

    {:ok, query} = Query.compile(user, "my:watched")

    images =
      Image.search_records(
        %{
          query: %{
            bool: %{
              must: query,
              must_not: [
                filter,
                %{term: %{hidden_from_users: true}}
              ]
            }
          },
          sort: %{created_at: :desc}
        },
        conn.assigns.image_pagination,
        Image |> preload(:tags)
      )

    conn
    |> render("index.rss", images: images)
  end
end