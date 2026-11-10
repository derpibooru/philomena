defmodule PhilomenaWeb.Image.DescriptionController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def update(conn, %{"image" => image_params} = params) do
    case Images.update_image_description(conn.assigns.actor, params["image_id"], image_params) do
      {:ok, {image, _old_description}} ->
        body = MarkdownRenderer.render_one(%{body: image.description}, conn)

        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_description.html",
          layout: false,
          image: image,
          body: body,
          changeset: Images.change_image(image)
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "_form.html", layout: false, image: changeset.data, changeset: changeset)

      {:error, _} = error ->
        error
    end
  end
end
