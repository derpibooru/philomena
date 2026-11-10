defmodule PhilomenaWeb.Search.ReverseController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports
  alias Philomena.DuplicateReports.SearchResult
  alias Philomena.Interactions

  plug PhilomenaWeb.ScraperCachePlug
  plug PhilomenaWeb.ScraperPlug, params_key: "image", params_name: "image"

  def index(conn, params) do
    create(conn, params)
  end

  def create(conn, %{"image" => image_params})
      when is_map(image_params) and image_params != %{} do
    upload = PhilomenaMedia.Upload.cast(image_params, "image")

    case DuplicateReports.create_reverse_search(conn.assigns.actor, image_params, upload) do
      {:ok, %SearchResult{} = result} ->
        interactions = Interactions.user_interactions(conn.assigns.actor, result.images)

        render(conn, "index.html",
          title: "Reverse Search",
          layout_class: "layout--wide",
          images: result.images,
          changeset: result.changeset,
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
    with {:ok, %SearchResult{} = result} <-
           DuplicateReports.create_reverse_search(conn.assigns.actor) do
      render(conn, "index.html",
        title: "Reverse Search",
        layout_class: "layout--wide",
        images: result.images,
        changeset: result.changeset
      )
    end
  end
end
