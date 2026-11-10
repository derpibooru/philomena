defmodule PhilomenaWeb.Image.SourceChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.SourceChanges
  alias Philomena.SourceChanges.SourceChangePage

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"image_id" => image_id} = params) do
    case SourceChanges.list_image_source_changes(
           conn.assigns.actor,
           image_id,
           params,
           conn.assigns.scrivener
         ) do
      {:ok, %SourceChangePage{target: image, source_changes: source_changes}, changeset} ->
        render(conn, "index.html",
          title: "Source Changes on Image #{image.id}",
          image: image,
          source_changes: source_changes,
          changeset: changeset
        )

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Invalid source change filter.")
        |> redirect(to: "/")

      error ->
        error
    end
  end
end
