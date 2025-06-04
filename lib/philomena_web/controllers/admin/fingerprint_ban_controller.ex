defmodule PhilomenaWeb.Admin.FingerprintBanController do
  use PhilomenaWeb, :controller

  alias Philomena.Bans.Fingerprint, as: FingerprintBan
  alias Philomena.Bans
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized

  plug :load_resource,
    model: FingerprintBan,
    as: :fingerprint_ban,
    only: [:edit, :update, :delete]

  plug :check_can_delete when action in [:delete]

  def index(conn, %{"bq" => q}) when is_binary(q) do
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
      {:ok, fingerprint_ban} ->
        conn
        |> put_flash(:info, "Fingerprint was successfully banned.")
        |> moderation_log(details: &log_details/2, data: fingerprint_ban)
        |> redirect(to: ~p"/admin/fingerprint_bans")

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    changeset = Bans.change_fingerprint(conn.assigns.fingerprint_ban)
    render(conn, "edit.html", title: "Editing Fingerprint Ban", changeset: changeset)
  end

  def update(conn, %{"fingerprint" => fingerprint_ban_params}) do
    case Bans.update_fingerprint(conn.assigns.fingerprint_ban, fingerprint_ban_params) do
      {:ok, fingerprint_ban} ->
        conn
        |> put_flash(:info, "Fingerprint ban successfully updated.")
        |> moderation_log(details: &log_details/2, data: fingerprint_ban)
        |> redirect(to: ~p"/admin/fingerprint_bans")

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    {:ok, fingerprint_ban} = Bans.delete_fingerprint(conn.assigns.fingerprint_ban)

    conn
    |> put_flash(:info, "Fingerprint ban successfully deleted.")
    |> moderation_log(details: &log_details/2, data: fingerprint_ban)
    |> redirect(to: ~p"/admin/fingerprint_bans")
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
    if Canada.Can.can?(conn.assigns.current_user, :index, FingerprintBan) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp check_can_delete(conn, _opts) do
    if conn.assigns.current_user.role == "admin" do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(action, ban) do
    body =
      case action do
        :create -> "Created a fingerprint ban #{ban.generated_ban_id}"
        :update -> "Updated a fingerprint ban #{ban.generated_ban_id}"
        :delete -> "Deleted a fingerprint ban #{ban.generated_ban_id}"
      end

    %{body: body, subject_path: ~p"/admin/fingerprint_bans"}
  end
end
