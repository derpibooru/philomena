defmodule PhilomenaWeb.Image.RelatedController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageScope
  alias Philomena.Images
  alias Philomena.Interactions

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    with {:ok, {image, images}} <-
           Images.list_related_images(
             conn.assigns.actor,
             ImageScope.search_scope(conn),
             params["image_id"]
           ) do
      interactions = Interactions.user_interactions(conn.assigns.actor, images)

      render(conn, "index.html",
        title: "##{image.id} - Related Images",
        layout_class: "layout--wide",
        image: image,
        images: images,
        interactions: interactions
      )
    end
  end
end
