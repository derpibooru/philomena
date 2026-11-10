defmodule PhilomenaWeb.Admin.Advert.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.Adverts

  action_fallback PhilomenaWeb.FallbackController

  def edit(conn, %{"advert_id" => id}) do
    with {:ok, {advert, changeset}} <-
           Adverts.edit_advert(conn.assigns.actor, id) do
      render(conn, "edit.html", title: "Editing Advert", advert: advert, changeset: changeset)
    end
  end

  def update(conn, %{"advert_id" => id, "advert" => advert_params}) do
    upload = PhilomenaMedia.Upload.cast(advert_params, "image")

    case Adverts.update_advert_image(conn.assigns.actor, id, upload) do
      {:ok, _advert} ->
        conn
        |> put_flash(:info, "Advert was successfully updated.")
        |> redirect(to: ~p"/admin/adverts")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", advert: changeset.data, changeset: changeset)

      error ->
        error
    end
  end
end
