defmodule PhilomenaWeb.Gallery.OrderController do
  use PhilomenaWeb, :controller

  alias Philomena.Galleries

  action_fallback PhilomenaWeb.FallbackController

  def update(conn, %{"gallery_id" => gallery_id} = params) do
    case Galleries.update_gallery_order(conn.assigns.actor, gallery_id, params) do
      {:ok, _reorder_form} ->
        json(conn, %{})

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "image_ids must be a non-empty subset of the gallery's images"})

      error ->
        error
    end
  end
end
