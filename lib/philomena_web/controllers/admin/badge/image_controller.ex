defmodule PhilomenaWeb.Admin.Badge.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.Badges

  action_fallback PhilomenaWeb.FallbackController

  def edit(conn, %{"badge_id" => id}) do
    with {:ok, {badge, changeset}} <- Badges.edit_badge(conn.assigns.actor, id) do
      render(conn, "edit.html", title: "Editing Badge", badge: badge, changeset: changeset)
    end
  end

  def update(conn, %{"badge_id" => id, "badge" => badge_params}) do
    upload = PhilomenaMedia.Upload.cast(badge_params, "image")

    case Badges.update_badge_image(conn.assigns.actor, id, upload) do
      {:ok, _badge} ->
        conn
        |> put_flash(:info, "Badge updated successfully.")
        |> redirect(to: ~p"/admin/badges")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", badge: changeset.data, changeset: changeset)

      error ->
        error
    end
  end
end
