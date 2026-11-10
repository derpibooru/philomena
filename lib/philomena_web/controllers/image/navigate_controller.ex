defmodule PhilomenaWeb.Image.NavigateController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageScope
  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"rel" => rel} = params) when rel in ~W(prev next) do
    scope = ImageScope.scope(conn)

    with {:ok, {image, result}} <-
           Images.list_image_navigation(
             conn.assigns.actor,
             ImageScope.search_scope(conn),
             params["image_id"]
           ) do
      case result do
        {next_image, hit} ->
          redirect(conn,
            to: ~p"/images/#{next_image}?#{Keyword.put(scope, :sort, hit["sort"])}"
          )

        nil ->
          redirect(conn, to: ~p"/images/#{image}?#{scope}")
      end
    else
      {:error, message} when is_binary(message) ->
        # The search query could not be compiled for this viewer, such as a
        # `my:` query from a signed-out visitor; stay on the current image.
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/images/#{params["image_id"]}?#{scope}")

      error ->
        error
    end
  end

  def index(conn, %{"rel" => "find"} = params) do
    with {:ok, page_num} <-
           Images.list_image_index_page(
             conn.assigns.actor,
             ImageScope.search_scope(conn),
             params["image_id"]
           ) do
      redirect(conn, to: ~p"/search?#{[q: "*", page: to_string(page_num), sf: "id"]}")
    end
  end
end
