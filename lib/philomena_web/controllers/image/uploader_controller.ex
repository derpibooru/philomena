defmodule PhilomenaWeb.Image.UploaderController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def update(conn, params) do
    case Images.update_image_uploader(conn.assigns.actor, params["image_id"], params["image"]) do
      {:ok, image} ->
        changeset = Images.change_image(image)

        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_uploader.html", layout: false, image: image, changeset: changeset)

      {:error, %Ecto.Changeset{}} ->
        update_failed(conn)

      error ->
        error
    end
  end

  # The form is submitted over AJAX; a 300 makes `ujs.ts` reload the page so the
  # flash renders.
  defp update_failed(conn) do
    conn
    |> put_flash(:error, "Failed to update uploader!")
    |> send_resp(:multiple_choices, "")
  end
end
