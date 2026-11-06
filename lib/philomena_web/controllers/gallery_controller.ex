defmodule PhilomenaWeb.GalleryController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageScope
  alias PhilomenaWeb.NotificationCountPlug
  alias Philomena.Galleries

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    case Galleries.list_galleries(
           conn.assigns.actor,
           query_param(params, "gallery"),
           conn.assigns.pagination
         ) do
      {:ok, galleries, changeset} ->
        render(
          conn,
          "index.html",
          title: "Galleries",
          galleries: galleries,
          changeset: changeset,
          layout_class: "layout--wide"
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        render(
          conn,
          "index.html",
          title: "Galleries",
          galleries: nil,
          changeset: changeset,
          layout_class: "layout--wide"
        )

      error ->
        error
    end
  end

  def show(conn, params) do
    case Galleries.show_gallery(
           conn.assigns.actor,
           ImageScope.search_scope(conn),
           params["id"]
         ) do
      {:ok, page} ->
        gallery_json = JSON.encode!(Enum.map(page.gallery_images, &elem(&1, 0).id))

        # The page load clears the gallery notification, so the header ticker
        # must be re-read afterwards.
        conn
        |> put_gallery_scope(page.gallery)
        |> NotificationCountPlug.call([])
        |> assign(:clientside_data, gallery_images: gallery_json)
        |> render("show.html",
          title: "Showing Gallery",
          layout_class: "layout--wide",
          watching: page.watching,
          gallery: page.gallery,
          gallery_prev: page.gallery_prev,
          gallery_next: page.gallery_next,
          gallery_images: page.gallery_images,
          images: page.images,
          interactions: page.interactions
        )

      {:error, _} = error ->
        error
    end
  end

  def new(conn, _params) do
    with {:ok, changeset} <- Galleries.new_gallery(conn.assigns.actor) do
      render(conn, "new.html", title: "New Gallery", changeset: changeset)
    end
  end

  def create(conn, params) do
    case Galleries.create_gallery(conn.assigns.actor, params["gallery"]) do
      {:ok, gallery} ->
        conn
        |> put_flash(:info, "Gallery successfully created.")
        |> redirect(to: ~p"/galleries/#{gallery}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      {:error, _} = error ->
        error
    end
  end

  def edit(conn, params) do
    with {:ok, {gallery, changeset}} <-
           Galleries.edit_gallery(conn.assigns.actor, params["id"]) do
      render(conn, "edit.html", title: "Editing Gallery", gallery: gallery, changeset: changeset)
    end
  end

  def update(conn, params) do
    case Galleries.update_gallery(conn.assigns.actor, params["id"], params["gallery"]) do
      {:ok, gallery} ->
        conn
        |> put_flash(:info, "Gallery successfully updated.")
        |> redirect(to: ~p"/galleries/#{gallery}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", gallery: changeset.data, changeset: changeset)

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, params) do
    with {:ok, _gallery} <- Galleries.delete_gallery(conn.assigns.actor, params["id"]) do
      conn
      |> put_flash(:info, "Gallery successfully destroyed.")
      |> redirect(to: ~p"/galleries")
    end
  end

  # Image links carry the gallery query and order, so navigation from an
  # image page stays within the gallery.
  defp put_gallery_scope(conn, gallery) do
    query = "gallery_id:#{gallery.id}"
    sort_direction = if gallery.order_position_asc, do: "asc", else: "desc"

    update_in(
      conn.params,
      &Map.merge(&1, %{"q" => query, "sf" => query, "sd" => sort_direction})
    )
  end
end
