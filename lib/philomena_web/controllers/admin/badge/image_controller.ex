defmodule PhilomenaWeb.Admin.Badge.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.Badges.Badge
  alias Philomena.Badges

  plug :verify_authorized
  plug :load_resource, model: Badge, id_name: "badge_id", persisted: true, only: [:edit, :update]

  def edit(conn, _params) do
    changeset = Badges.change_badge(conn.assigns.badge)
    render(conn, "edit.html", title: "Editing Badge", changeset: changeset)
  end

  def update(conn, %{"badge" => badge_params}) do
    case Badges.update_badge_image(conn.assigns.badge, badge_params) do
      {:ok, _badge} ->
        conn
        |> put_flash(:info, "Badge updated successfully.")
        |> redirect(to: Routes.admin_badge_path(conn, :index))

      {:error, :badge, changeset, _changes} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, Badge) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
