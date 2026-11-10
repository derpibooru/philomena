defmodule PhilomenaWeb.Gallery.SubscriptionController do
  use PhilomenaWeb, :controller

  alias Philomena.Galleries

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    case Galleries.create_gallery_subscription(conn.assigns.actor, params["gallery_id"]) do
      {:ok, gallery} ->
        render(conn, "_subscription.html", gallery: gallery, watching: true, layout: false)

      {:error, %Ecto.Changeset{}} ->
        render(conn, "_error.html", layout: false)

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, params) do
    with {:ok, gallery} <-
           Galleries.delete_gallery_subscription(conn.assigns.actor, params["gallery_id"]) do
      render(conn, "_subscription.html", gallery: gallery, watching: false, layout: false)
    end
  end
end
