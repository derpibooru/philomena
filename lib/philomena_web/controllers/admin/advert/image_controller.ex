defmodule PhilomenaWeb.Admin.Advert.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.Adverts.Advert
  alias Philomena.Adverts

  plug :verify_authorized

  plug :load_and_authorize_resource,
    model: Advert,
    id_name: "advert_id",
    persisted: true,
    only: [:edit, :update, :delete]

  def edit(conn, _params) do
    changeset = Adverts.change_advert(conn.assigns.advert)
    render(conn, "edit.html", title: "Editing Advert", changeset: changeset)
  end

  def update(conn, %{"advert" => advert_params}) do
    case Adverts.update_advert_image(conn.assigns.advert, advert_params) do
      {:ok, advert} ->
        conn
        |> put_flash(:info, "Advert was successfully updated.")
        |> moderation_log(details: &log_details/2, data: advert)
        |> redirect(to: ~p"/admin/adverts")

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :index, Advert) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(_action, advert) do
    %{body: "Updated image for advert #{advert.id}", subject_path: ~p"/admin/adverts"}
  end
end
