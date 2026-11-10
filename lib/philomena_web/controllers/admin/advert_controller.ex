defmodule PhilomenaWeb.Admin.AdvertController do
  use PhilomenaWeb, :controller

  alias Philomena.Adverts

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, _params) do
    with {:ok, adverts} <- Adverts.list_adverts(conn.assigns.actor, conn.assigns.scrivener) do
      render(conn, "index.html",
        title: "Admin - Adverts",
        layout_class: "layout--wide",
        adverts: adverts
      )
    end
  end

  def new(conn, _params) do
    with {:ok, changeset} <- Adverts.new_advert(conn.assigns.actor) do
      render(conn, "new.html", title: "New Advert", changeset: changeset)
    end
  end

  def create(conn, %{"advert" => advert_params}) do
    upload = PhilomenaMedia.Upload.cast(advert_params, "image")

    case Adverts.create_advert(conn.assigns.actor, advert_params, upload) do
      {:ok, _advert} ->
        conn
        |> put_flash(:info, "Advert was successfully created.")
        |> redirect(to: ~p"/admin/adverts")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      {:error, reason} = error when reason in [:unauthorized, :ban] ->
        error
    end
  end

  def edit(conn, %{"id" => id}) do
    with {:ok, {advert, changeset}} <- Adverts.edit_advert(conn.assigns.actor, id) do
      render(conn, "edit.html", title: "Editing Advert", advert: advert, changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "advert" => advert_params}) do
    case Adverts.update_advert(conn.assigns.actor, id, advert_params) do
      {:ok, _advert} ->
        conn
        |> put_flash(:info, "Advert was successfully updated.")
        |> redirect(to: ~p"/admin/adverts")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", advert: changeset.data, changeset: changeset)

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, _advert} <- Adverts.delete_advert(conn.assigns.actor, id) do
      conn
      |> put_flash(:info, "Advert was successfully deleted.")
      |> redirect(to: ~p"/admin/adverts")
    end
  end
end
