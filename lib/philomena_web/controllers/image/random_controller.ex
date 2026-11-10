defmodule PhilomenaWeb.Image.RandomController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageScope
  alias Philomena.Images

  def index(conn, _params) do
    scope = ImageScope.scope(conn)

    case Images.list_random_images(conn.assigns.actor, ImageScope.search_scope(conn)) do
      {:ok, nil} ->
        redirect(conn, to: ~p"/images")

      {:ok, random_id} ->
        redirect(conn, to: ~p"/images/#{random_id}?#{scope}")

      {:error, _invalid_query} ->
        redirect(conn, to: ~p"/images")
    end
  end
end
