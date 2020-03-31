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
      {:ok, _advert} ->
        conn
        |> put_flash(:info, "Advert was successfully updated.")
        |> redirect(to: Routes.admin_advert_path(conn, :index))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, Advert) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
