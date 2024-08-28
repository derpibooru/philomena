defmodule PhilomenaWeb.Search.ReverseController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports.SearchQuery
  alias Philomena.DuplicateReports
  alias Philomena.Interactions

  plug PhilomenaWeb.ScraperCachePlug
  plug PhilomenaWeb.ScraperPlug, params_key: "image", params_name: "image"

  def index(conn, params) do
    create(conn, params)
  end

  def create(conn, %{"image" => image_params})
      when is_map(image_params) and image_params != %{} do
    case DuplicateReports.execute_search_query(image_params) do
      {:ok, images} ->
        changeset = DuplicateReports.change_search_query(%SearchQuery{})
        interactions = Interactions.user_interactions(images, conn.assigns.current_user)

        render(conn, "index.html",
          title: "Reverse Search",
          layout_class: "layout--wide",
          images: images,
          changeset: changeset,
          interactions: interactions
        )

      {:error, changeset} ->
        render(conn, "index.html",
          title: "Reverse Search",
          layout_class: "layout--wide",
          images: nil,
          changeset: changeset
        )
    end
  end

  def create(conn, _params) do
    changeset = DuplicateReports.change_search_query(%SearchQuery{})

    render(conn, "index.html",
      title: "Reverse Search",
      layout_class: "layout--wide",
      images: nil,
      changeset: changeset
    )
  end
end
