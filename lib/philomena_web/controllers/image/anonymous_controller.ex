defmodule PhilomenaWeb.Image.AnonymousController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    with {:ok, image} <-
           Images.update_anonymous(conn.assigns.actor, params["image_id"], true) do
      conn
      |> put_flash(:info, "Successfully updated anonymity.")
      |> redirect(to: ~p"/images/#{image}")
    end
  end

  def delete(conn, params) do
    with {:ok, image} <-
           Images.update_anonymous(conn.assigns.actor, params["image_id"], false) do
      conn
      |> put_flash(:info, "Successfully updated anonymity.")
      |> redirect(to: ~p"/images/#{image}")
    end
  end
end
