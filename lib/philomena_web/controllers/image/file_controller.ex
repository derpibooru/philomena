defmodule PhilomenaWeb.Image.FileController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  plug PhilomenaWeb.ScraperPlug, params_name: "image", params_key: "image"

  def update(conn, %{"image" => image_params} = params) do
    upload = PhilomenaMedia.Upload.cast(image_params, "image")

    case Images.update_image_file(conn.assigns.actor, params["image_id"], upload) do
      {:ok, image} ->
        conn
        |> put_flash(:info, "Successfully updated file.")
        |> redirect(to: ~p"/images/#{image}")

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Failed to update file!")
        |> redirect(to: ~p"/images/#{params["image_id"]}")

      {:error, _} = error ->
        error
    end
  end
end
