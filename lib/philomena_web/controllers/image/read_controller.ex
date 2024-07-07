defmodule PhilomenaWeb.Image.ReadController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug :load_resource, model: Image, id_name: "image_id", persisted: true

  def create(conn, _params) do
    image = conn.assigns.image
    user = conn.assigns.current_user

    Images.clear_image_notification(image, user)

    send_resp(conn, :ok, "")
  end
end
