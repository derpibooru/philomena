defmodule PhilomenaWeb.Image.SubscriptionController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    case Images.create_image_subscription(conn.assigns.actor, params["image_id"]) do
      {:ok, image} ->
        render(conn, "_subscription.html", image: image, watching: true, layout: false)

      {:error, %Ecto.Changeset{}} ->
        render(conn, "_error.html", layout: false)

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, params) do
    with {:ok, image} <- Images.delete_image_subscription(conn.assigns.actor, params["image_id"]) do
      render(conn, "_subscription.html", image: image, watching: false, layout: false)
    end
  end
end
