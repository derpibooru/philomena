defmodule PhilomenaWeb.Admin.FingerprintBanController do
  use PhilomenaWeb, :controller

  alias Philomena.Bans

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    case Bans.list_fingerprint_bans(conn.assigns.actor, params, conn.assigns.scrivener) do
      {:ok, fingerprint_bans, changeset} ->
        render(conn, "index.html",
          title: "Admin - Fingerprint Bans",
          layout_class: "layout--wide",
          fingerprint_bans: fingerprint_bans,
          changeset: changeset
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "index.html",
          title: "Admin - Fingerprint Bans",
          layout_class: "layout--wide",
          fingerprint_bans: nil,
          changeset: changeset
        )

      error ->
        error
    end
  end

  def new(conn, params) do
    with {:ok, changeset} <-
           Bans.new_fingerprint_ban(conn.assigns.actor, params["fingerprint"]) do
      render(conn, "new.html", title: "New Fingerprint Ban", changeset: changeset)
    end
  end

  def create(conn, %{"fingerprint" => fingerprint_ban_params}) do
    case Bans.create_fingerprint_ban(conn.assigns.actor, fingerprint_ban_params) do
      {:ok, _fingerprint_ban} ->
        conn
        |> put_flash(:info, "Fingerprint was successfully banned.")
        |> redirect(to: ~p"/admin/fingerprint_bans")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      error ->
        error
    end
  end

  def edit(conn, params) do
    with {:ok, {fingerprint_ban, changeset}} <-
           Bans.edit_fingerprint_ban(conn.assigns.actor, params["id"]) do
      render(conn, "edit.html",
        title: "Editing Fingerprint Ban",
        fingerprint_ban: fingerprint_ban,
        changeset: changeset
      )
    end
  end

  def update(conn, %{"id" => id, "fingerprint" => fingerprint_ban_params}) do
    case Bans.update_fingerprint_ban(conn.assigns.actor, id, fingerprint_ban_params) do
      {:ok, _fingerprint_ban} ->
        conn
        |> put_flash(:info, "Fingerprint ban successfully updated.")
        |> redirect(to: ~p"/admin/fingerprint_bans")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", fingerprint_ban: changeset.data, changeset: changeset)

      error ->
        error
    end
  end

  def delete(conn, params) do
    with {:ok, _fingerprint_ban} <-
           Bans.delete_fingerprint_ban(conn.assigns.actor, params["id"]) do
      conn
      |> put_flash(:info, "Fingerprint ban successfully deleted.")
      |> redirect(to: ~p"/admin/fingerprint_bans")
    end
  end
end
