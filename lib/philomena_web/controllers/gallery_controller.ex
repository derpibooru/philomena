defmodule PhilomenaWeb.GalleryController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias PhilomenaWeb.NotificationCountPlug
  alias Philomena.Elasticsearch
  alias Philomena.ImageSorter
  alias Philomena.Interactions
  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries
  import Ecto.Query

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create, :edit, :update, :delete]

  plug :load_and_authorize_resource,
    model: Gallery,
    except: [:index],
    preload: [:creator, thumbnail: :tags]

  def index(conn, params) do
    galleries =
      Elasticsearch.search_records(
        Gallery,
        %{
          query: %{
            bool: %{
              must: parse_search(params)
            }
          },
          sort: parse_sort(params)
        },
        conn.assigns.pagination,
        Gallery |> preload([:creator, thumbnail: :tags])
      )

    render(conn, "index.html",
      title: "Galleries",
      galleries: galleries,
      layout_class: "layout--wide"
    )
  end

  def show(conn, _params) do
    gallery = conn.assigns.gallery
    user = conn.assigns.current_user
    query = "gallery_id:#{gallery.id}"

    params =
      Map.merge(conn.params, %{
        "q" => query,
        "sf" => "gallery_id:#{gallery.id}",
        "sd" => position_order(gallery)
      })

    sort = ImageSorter.parse_sort(params)

    {:ok, {images, _tags}} =
      ImageLoader.search_string(conn, query, queries: sort.queries, sorts: sort.sorts)

    interactions = Interactions.user_interactions(images, user)

    watching = Galleries.subscribed?(gallery, user)
    gallery_images = Jason.encode!(Enum.map(images, & &1.id))

    Galleries.clear_notification(gallery, user)

    conn
    |> NotificationCountPlug.call([])
    |> Map.put(:params, params)
    |> assign(:clientside_data, gallery_images: gallery_images)
    |> render("show.html",
      title: "Showing Gallery",
      layout_class: "layout--wide",
      watching: watching,
      gallery: gallery,
      images: images,
      interactions: interactions
    )
  end

  def new(conn, _params) do
    changeset = Galleries.change_gallery(%Gallery{})
    render(conn, "new.html", title: "New Gallery", changeset: changeset)
  end

  def create(conn, %{"gallery" => gallery_params}) do
    user = conn.assigns.current_user

    case Galleries.create_gallery(user, gallery_params) do
      {:ok, gallery} ->
        Galleries.reindex_gallery(gallery)

        conn
        |> put_flash(:info, "Gallery successfully created.")
        |> redirect(to: Routes.gallery_path(conn, :show, gallery))

      {:error, changeset} ->
        conn
        |> render("new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    gallery = conn.assigns.gallery
    changeset = Galleries.change_gallery(gallery)

    render(conn, "edit.html", title: "Editing Gallery", gallery: gallery, changeset: changeset)
  end

  def update(conn, %{"gallery" => gallery_params}) do
    gallery = conn.assigns.gallery

    case Galleries.update_gallery(gallery, gallery_params) do
      {:ok, gallery} ->
        Galleries.reindex_gallery(gallery)

        conn
        |> put_flash(:info, "Gallery successfully updated.")
        |> redirect(to: Routes.gallery_path(conn, :show, gallery))

      {:error, changeset} ->
        conn
        |> render("edit.html", gallery: gallery, changeset: changeset)
    end
  end

  def delete(conn, _params) do
    gallery = conn.assigns.gallery

    {:ok, _gallery} = Galleries.delete_gallery(gallery)
    Galleries.unindex_gallery(gallery)

    conn
    |> put_flash(:info, "Gallery successfully destroyed.")
    |> redirect(to: Routes.gallery_path(conn, :index))
  end

  defp parse_search(%{"gallery" => gallery_params}) do
    parse_title(gallery_params) ++
      parse_creator(gallery_params) ++
      parse_included_image(gallery_params) ++
      parse_description(gallery_params)
  end

  defp parse_search(_params), do: [%{match_all: %{}}]

  defp parse_title(%{"title" => title}) when is_binary(title) and title not in [nil, ""],
    do: [%{wildcard: %{title: "*" <> String.downcase(title) <> "*"}}]

  defp parse_title(_params), do: []

  defp parse_creator(%{"creator" => creator})
       when is_binary(creator) and creator not in [nil, ""],
       do: [%{term: %{creator: String.downcase(creator)}}]

  defp parse_creator(_params), do: []

  defp parse_included_image(%{"include_image" => image_id})
       when is_binary(image_id) and image_id not in [nil, ""] do
    with {image_id, _rest} <- Integer.parse(image_id) do
      [%{term: %{image_ids: image_id}}]
    else
      _ ->
        []
    end
  end

  defp parse_included_image(_params), do: []

  defp parse_description(%{"description" => description})
       when is_binary(description) and description not in [nil, ""],
       do: [%{match_phrase: %{description: description}}]

  defp parse_description(_params), do: []

  defp parse_sort(%{"gallery" => %{"sf" => sf, "sd" => sd}})
       when sf in ["created_at", "updated_at", "image_count", "_score"] and
              sd in ["desc", "asc"] do
    %{sf => sd}
  end

  defp parse_sort(_params) do
    %{created_at: :desc}
  end

  defp position_order(%{order_position_asc: true}), do: "asc"
  defp position_order(_gallery), do: "desc"
end
