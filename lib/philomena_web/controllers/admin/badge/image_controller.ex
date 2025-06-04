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

  defp log_details(_action, badge) do
    %{body: "Updated image of badge '#{badge.title}'", subject_path: ~p"/admin/badges"}
  end
end
