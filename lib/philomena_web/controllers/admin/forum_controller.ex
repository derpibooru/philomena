defmodule PhilomenaWeb.Admin.ForumController do
  use PhilomenaWeb, :controller

  alias Philomena.Forums

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, _params) do
    with {:ok, forums} <- Forums.list_admin_forums(conn.assigns.actor) do
      render(conn, "index.html", title: "Admin - Forums", forums: forums)
    end
  end

  def new(conn, _params) do
    with {:ok, changeset} <- Forums.new_forum(conn.assigns.actor) do
      render(conn, "new.html", title: "New Forum", changeset: changeset)
    end
  end

  def create(conn, %{"forum" => forum_params}) do
    case Forums.create_forum(conn.assigns.actor, forum_params) do
      {:ok, _forum} ->
        conn
        |> put_flash(:info, "Forum created successfully.")
        |> redirect(to: ~p"/admin/forums")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      {:error, reason} = error when reason in [:ban, :unauthorized] ->
        error
    end
  end

  def edit(conn, params) do
    with {:ok, {forum, changeset}} <-
           Forums.edit_forum(conn.assigns.actor, params["id"]) do
      render(conn, "edit.html", title: "Editing Forum", forum: forum, changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "forum" => forum_params}) do
    case Forums.update_forum(conn.assigns.actor, id, forum_params) do
      {:ok, _forum} ->
        conn
        |> put_flash(:info, "Forum updated successfully.")
        |> redirect(to: ~p"/admin/forums")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", forum: changeset.data, changeset: changeset)

      {:error, _} = error ->
        error
    end
  end
end
