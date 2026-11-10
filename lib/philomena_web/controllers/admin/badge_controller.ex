defmodule PhilomenaWeb.Admin.BadgeController do
  use PhilomenaWeb, :controller

  alias Philomena.Badges

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, _params) do
    with {:ok, badges} <- Badges.list_badges(conn.assigns.actor, conn.assigns.scrivener) do
      render(conn, "index.html", title: "Admin - Badges", badges: badges)
    end
  end

  def new(conn, _params) do
    with {:ok, changeset} <- Badges.new_badge(conn.assigns.actor) do
      render(conn, "new.html", title: "New Badge", changeset: changeset)
    end
  end

  def create(conn, %{"badge" => badge_params}) do
    upload = PhilomenaMedia.Upload.cast(badge_params, "image")

    case Badges.create_badge(conn.assigns.actor, badge_params, upload) do
      {:ok, _badge} ->
        conn
        |> put_flash(:info, "Badge created successfully.")
        |> redirect(to: ~p"/admin/badges")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      {:error, reason} = error when reason in [:ban, :unauthorized] ->
        error
    end
  end

  def edit(conn, %{"id" => id}) do
    with {:ok, {badge, changeset}} <- Badges.edit_badge(conn.assigns.actor, id) do
      render(conn, "edit.html", title: "Editing Badge", badge: badge, changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "badge" => badge_params}) do
    case Badges.update_badge(conn.assigns.actor, id, badge_params) do
      {:ok, _badge} ->
        conn
        |> put_flash(:info, "Badge updated successfully.")
        |> redirect(to: ~p"/admin/badges")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", badge: changeset.data, changeset: changeset)

      {:error, _} = error ->
        error
    end
  end
end
