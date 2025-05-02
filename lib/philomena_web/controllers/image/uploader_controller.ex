defmodule PhilomenaWeb.Image.UploaderController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images
  alias Philomena.Repo

  plug :verify_authorized
  plug :load_resource, model: Image, id_name: "image_id", persisted: true

  def update(conn, %{"image" => image_params}) do
    {:ok, image} = Images.update_uploader(conn.assigns.image, image_params)

    Images.reindex_image(image)

    image = Repo.preload(image, user: [awards: :badge])
    changeset = Images.change_image(image)

    conn
    |> put_view(PhilomenaWeb.ImageView)
    |> moderation_log(details: &log_details/2, data: image)
    |> render("_uploader.html", layout: false, image: image, changeset: changeset)
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :show, :ip_address) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(_action, image) do
    %{body: "Changed uploader of image #{image.id}", subject_path: ~p"/images/#{image}"}
  end
end
