defmodule PhilomenaWeb.Gallery.ReadController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries

  plug :load_resource, model: Gallery, id_name: "gallery_id", persisted: true

  def create(conn, _params) do
    gallery = conn.assigns.gallery
    user = conn.assigns.current_user

    Galleries.clear_notification(gallery, user)

    send_resp(conn, :ok, "")
  end
end