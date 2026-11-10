defmodule PhilomenaWeb.SearchController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageScope
  alias PhilomenaWeb.TagInfoRenderer
  alias Philomena.Images
  alias Philomena.Interactions

  def index(conn, params) do
    case Images.query_images(conn.assigns.actor, ImageScope.search_scope(conn)) do
      {:ok, %{images: images, tags: tags}} ->
        interactions = Interactions.user_interactions(conn.assigns.actor, images)

        render(conn, "index.html",
          title: "Searching for #{params["q"]}",
          images: images,
          tags: TagInfoRenderer.render_tag_info(tags, conn),
          search_query: params["q"],
          interactions: interactions,
          layout_class: "layout--wide"
        )

      {:error, msg} ->
        render(conn, "index.html",
          title: "Searching for #{params["q"]}",
          images: [],
          tags: [],
          error: msg,
          search_query: params["q"]
        )
    end
  end
end
