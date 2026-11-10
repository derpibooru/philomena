defmodule PhilomenaWeb.Image.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChangePage

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"image_id" => image_id} = params) do
    case TagChanges.list_image_tag_changes(
           conn.assigns.actor,
           image_id,
           params,
           conn.assigns.pagination
         ) do
      {:ok, %TagChangePage{target: image, tag_changes: tag_changes}, changeset} ->
        path = ~p"/images/#{image}/tag_changes"

        conn
        |> put_view(PhilomenaWeb.TagChangeView)
        |> render("index.html",
          title: "Tag Changes for Image ##{image.id}",
          path: path,
          pagination_route: fn query -> "#{path}?#{Plug.Conn.Query.encode(query)}" end,
          tag_changes: tag_changes,
          changeset: changeset
        )

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Invalid tag change query.")
        |> redirect(to: "/tag_changes")

      error ->
        error
    end
  end
end
