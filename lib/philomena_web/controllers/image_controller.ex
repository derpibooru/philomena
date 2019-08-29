defmodule PhilomenaWeb.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.{Images, Images.Image}
  import Ecto.Query

  plug ImageFilter

  def index(conn, _params) do
    query = conn.assigns[:compiled_filter]
    images =
      Image.search_records(
        %{
          query: %{bool: %{must_not: query}},
          sort: %{created_at: :desc}
        },
        Image |> preload(:tags)
      )

    render(conn, "index.html", images: images)
  end

  def new(conn, _params) do
    changeset = Images.change_image(%Image{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"image" => image_params}) do
    case Images.create_image(image_params) do
      {:ok, image} ->
        conn
        |> put_flash(:info, "Image created successfully.")
        |> redirect(to: Routes.image_path(conn, :show, image))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    image = Images.get_image!(id)
    render(conn, "show.html", image: image)
  end
end
