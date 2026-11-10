defmodule PhilomenaWeb.Image.VoteController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images
  alias PhilomenaWeb.Api.Json.ImageView

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"image_id" => image_id} = params) do
    case Images.create_image_vote(conn.assigns.actor, image_id, params) do
      {:ok, image} ->
        json(conn, Image.interaction_data(image))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(400)
        |> put_view(ImageView)
        |> render("error.json", changeset: changeset)

      error ->
        error
    end
  end

  def delete(conn, %{"image_id" => image_id}) do
    with {:ok, image} <- Images.delete_image_vote(conn.assigns.actor, image_id) do
      json(conn, Image.interaction_data(image))
    end
  end
end
