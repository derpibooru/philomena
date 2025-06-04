defmodule PhilomenaWeb.Admin.BadgeController do
  use PhilomenaWeb, :controller

  alias Philomena.Badges.Badge
  alias Philomena.Badges
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized
  plug :load_resource, model: Badge, only: [:edit, :update]

  def index(conn, _params) do
    badges =
      Badge
      |> order_by(asc: :title)
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html", title: "Admin - Badges", badges: badges)
  end

  def new(conn, _params) do
    changeset = Badges.change_badge(%Badge{})
    render(conn, "new.html", title: "New Badge", changeset: changeset)
  end

  def create(conn, %{"badge" => badge_params}) do
    case Badges.create_badge(badge_params) do
      {:ok, badge} ->
        conn
        |> put_flash(:info, "Badge created successfully.")
        |> moderation_log(details: &log_details/2, data: badge)
        |> redirect(to: ~p"/admin/badges")

      {:error, :badge, changeset, _changes} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    changeset = Badges.change_badge(conn.assigns.badge)
    render(conn, "edit.html", title: "Editing Badge", changeset: changeset)
  end

  def update(conn, %{"badge" => badge_params}) do
    case Badges.update_badge(conn.assigns.badge, badge_params) do
      {:ok, badge} ->
        conn
        |> put_flash(:info, "Badge updated successfully.")
        |> moderation_log(details: &log_details/2, data: badge)
        |> redirect(to: ~p"/admin/badges")

      {:error, :badge, changeset, _changes} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :index, Badge) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(action, badge) do
    body =
      case action do
        :create -> "Created badge '#{badge.title}'"
        :update -> "Updated badge '#{badge.title}'"
      end

    %{body: body, subject_path: ~p"/admin/badges"}
  end
end
