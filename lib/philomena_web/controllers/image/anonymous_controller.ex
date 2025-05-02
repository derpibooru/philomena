defmodule PhilomenaWeb.Image.AnonymousController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug :verify_authorized
  plug :load_resource, model: Image, id_name: "image_id", persisted: true

  def create(conn, _params) do
    Images.update_anonymous(conn.assigns.image, %{"anonymous" => true})
    |> process_request(conn)
  end

  def delete(conn, _params) do
    Images.update_anonymous(conn.assigns.image, %{"anonymous" => false})
    |> process_request(conn)
  end

  defp process_request({:ok, image}, conn) do
    Images.reindex_image(image)

    conn
    |> put_flash(:info, "Successfully updated anonymity.")
    |> moderation_log(details: &log_details/2, data: image)
    |> redirect(to: ~p"/images/#{image}")
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :show, :ip_address) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(_action, image) do
    %{
      body: "Updated anonymity of image #{image.id}",
      subject_path: ~p"/images/#{image}"
    }
  end
end
