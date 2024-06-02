defmodule PhilomenaWeb.Admin.SiteNoticeController do
  use PhilomenaWeb, :controller

  alias Philomena.SiteNotices.SiteNotice
  alias Philomena.SiteNotices
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized
  plug :load_and_authorize_resource, model: SiteNotice, except: [:index]

  def index(conn, _params) do
    site_notices =
      SiteNotice
      |> order_by(desc: :start_date)
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html", title: "Admin - Site Notices", admin_site_notices: site_notices)
  end

  def new(conn, _params) do
    changeset = SiteNotices.change_site_notice(%SiteNotice{})
    render(conn, "new.html", title: "New Site Notice", changeset: changeset)
  end

  def create(conn, %{"site_notice" => site_notice_params}) do
    case SiteNotices.create_site_notice(conn.assigns.current_user, site_notice_params) do
      {:ok, _site_notice} ->
        conn
        |> put_flash(:info, "Successfully created site notice.")
        |> redirect(to: ~p"/admin/site_notices")

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    changeset = SiteNotices.change_site_notice(conn.assigns.site_notice)
    render(conn, "edit.html", title: "Editing Site Notices", changeset: changeset)
  end

  def update(conn, %{"site_notice" => site_notice_params}) do
    case SiteNotices.update_site_notice(conn.assigns.site_notice, site_notice_params) do
      {:ok, _site_notice} ->
        conn
        |> put_flash(:info, "Succesfully updated site notice.")
        |> redirect(to: ~p"/admin/site_notices")

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    {:ok, _site_notice} = SiteNotices.delete_site_notice(conn.assigns.site_notice)

    conn
    |> put_flash(:info, "Sucessfully deleted site notice.")
    |> redirect(to: ~p"/admin/site_notices")
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, SiteNotice) do
      true -> conn
      false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
