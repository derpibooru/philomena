defmodule PhilomenaWeb.Admin.FingerprintBanController do
  use PhilomenaWeb, :controller

  alias Philomena.Bans.Fingerprint, as: FingerprintBan
  alias Philomena.Bans
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized
  plug :load_resource, model: FingerprintBan, only: [:edit, :update, :delete]
  plug :check_can_delete when action in [:delete]

  def index(conn, %{"q" => q}) when is_binary(q) do
    FingerprintBan
    |> where(
      [fb],
      ilike(fb.fingerprint, ^"%#{q}%") or
        fb.generated_ban_id == ^q or
        fragment("to_tsvector(?) @@ plainto_tsquery(?)", fb.reason, ^q) or
        fragment("to_tsvector(?) @@ plainto_tsquery(?)", fb.note, ^q)
    )
    |> load_bans(conn)
  end

  def index(conn, %{"fingerprint" => fingerprint}) when is_binary(fingerprint) do
    FingerprintBan
    |> where(fingerprint: ^fingerprint)
    |> load_bans(conn)
  end

  def index(conn, _params) do
    load_bans(FingerprintBan, conn)
  end

  def new(conn, %{"fingerprint" => fingerprint}) do
    changeset = Bans.change_fingerprint(%FingerprintBan{fingerprint: fingerprint})
    render(conn, "new.html", title: "New Fingerprint Ban", changeset: changeset)
  end

  def new(conn, _params) do
    changeset = Bans.change_fingerprint(%FingerprintBan{})
    render(conn, "new.html", title: "New Fingerprint Ban", changeset: changeset)
  end

  def create(conn, %{"fingerprint" => fingerprint_ban_params}) do
    case Bans.create_fingerprint(conn.assigns.current_user, fingerprint_ban_params) do
      {:ok, _fingerprint_ban} ->
        conn
        |> put_flash(:info, "Fingerprint was successfully banned.")
        |> redirect(to: Routes.admin_fingerprint_ban_path(conn, :index))

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    changeset = Bans.change_fingerprint(conn.assigns.fingerprint)
    render(conn, "edit.html", title: "Editing Fingerprint Ban", changeset: changeset)
  end

  def update(conn, %{"fingerprint" => fingerprint_ban_params}) do
    case Bans.update_fingerprint(conn.assigns.fingerprint, fingerprint_ban_params) do
      {:ok, _fingerprint_ban} ->
        conn
        |> put_flash(:info, "Fingerprint ban successfully updated.")
        |> redirect(to: Routes.admin_fingerprint_ban_path(conn, :index))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    {:ok, _fingerprint_ban} = Bans.delete_fingerprint(conn.assigns.fingerprint)

    conn
    |> put_flash(:info, "Fingerprint ban successfully deleted.")
    |> redirect(to: Routes.admin_fingerprint_ban_path(conn, :index))
  end

  defp load_bans(queryable, conn) do
    fingerprint_bans =
      queryable
      |> order_by(desc: :created_at)
      |> preload(:banning_user)
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html",
      layout_class: "layout--wide",
      title: "Admin - Fingerprint Bans",
      fingerprint_bans: fingerprint_bans
    )
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, FingerprintBan) do
      true -> conn
      false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp check_can_delete(conn, _opts) do
    case conn.assigns.current_user.role == "admin" do
      true -> conn
      false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
