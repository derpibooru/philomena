defmodule PhilomenaWeb.Admin.SiteNoticeController do
  use PhilomenaWeb, :controller

  alias Philomena.SiteNotices

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, _params) do
    with {:ok, site_notices} <-
           SiteNotices.list_site_notices(conn.assigns.actor, conn.assigns.scrivener) do
      render(conn, "index.html", title: "Admin - Site Notices", admin_site_notices: site_notices)
    end
  end

  def new(conn, _params) do
    with {:ok, changeset} <- SiteNotices.new_site_notice(conn.assigns.actor) do
      render(conn, "new.html", title: "New Site Notice", changeset: changeset)
    end
  end

  def create(conn, %{"site_notice" => site_notice_params}) do
    case SiteNotices.create_site_notice(conn.assigns.actor, site_notice_params) do
      {:ok, _site_notice} ->
        conn
        |> put_flash(:info, "Successfully created site notice.")
        |> redirect(to: ~p"/admin/site_notices")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      {:error, reason} = error when reason in [:ban, :unauthorized] ->
        error
    end
  end

  def edit(conn, params) do
    with {:ok, {site_notice, changeset}} <-
           SiteNotices.edit_site_notice(conn.assigns.actor, params["id"]) do
      render(conn, "edit.html",
        title: "Editing Site Notices",
        site_notice: site_notice,
        changeset: changeset
      )
    end
  end

  def update(conn, %{"id" => id, "site_notice" => site_notice_params}) do
    case SiteNotices.update_site_notice(conn.assigns.actor, id, site_notice_params) do
      {:ok, _site_notice} ->
        conn
        |> put_flash(:info, "Successfully updated site notice.")
        |> redirect(to: ~p"/admin/site_notices")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", site_notice: changeset.data, changeset: changeset)

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, params) do
    with {:ok, _site_notice} <-
           SiteNotices.delete_site_notice(conn.assigns.actor, params["id"]) do
      conn
      |> put_flash(:info, "Successfully deleted site notice.")
      |> redirect(to: ~p"/admin/site_notices")
    end
  end
end
