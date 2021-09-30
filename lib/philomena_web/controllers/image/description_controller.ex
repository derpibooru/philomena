defmodule PhilomenaWeb.Image.DescriptionController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.CanaryMapPlug, update: :edit_description

  plug :load_and_authorize_resource,
    model: Image,
    id_name: "image_id",
    persisted: true,
    preload: [:user, tags: :aliases]

  def update(conn, %{"image" => image_params}) do
    image = conn.assigns.image
    old_description = image.description

    case Images.update_description(image, image_params) do
      {:ok, image} ->
        PhilomenaWeb.Endpoint.broadcast!(
          "firehose",
          "image:description_update",
          %{image_id: image.id, added: image.description, removed: old_description}
        )

        PhilomenaWeb.Endpoint.broadcast!(
          "firehose",
          "image:update",
          PhilomenaWeb.Api.Json.ImageView.render("show.json", %{image: image, interactions: []})
        )

        Images.reindex_image(image)

        body = MarkdownRenderer.render_one(%{body: image.description}, conn)

        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_description.html", layout: false, image: image, body: body)

      {:error, changeset} ->
        conn
        |> render("_form.html", layout: false, image: image, changeset: changeset)
    end
  end
end
