defmodule PhilomenaWeb.Image.DescriptionController do
  use PhilomenaWeb, :controller

  alias Philomena.Textile.Renderer
  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.CanaryMapPlug, update: :edit_description
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def update(conn, %{"image" => image_params}) do
    image = conn.assigns.image

    case Images.update_description(image, image_params) do
      {:ok, image} ->
        Images.reindex_image(image)

        body = Renderer.render_one(%{body: image.description}, conn)

        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_description.html", layout: false, image: image, body: body)

      {:error, changeset} ->
        conn
        |> render("_form.html", layout: false, image: image, changeset: changeset)
    end
  end
end