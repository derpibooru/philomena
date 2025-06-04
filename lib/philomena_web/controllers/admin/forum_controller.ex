defmodule PhilomenaWeb.Admin.ForumController do
  use PhilomenaWeb, :controller

  alias Philomena.Forums.Forum
  alias Philomena.Forums

  plug :verify_authorized
  plug :load_resource, model: Forum, id_field: "short_name"

  def index(conn, _params) do
    render(conn, "index.html", title: "Admin - Forums")
  end

  def new(conn, _params) do
    changeset = Forums.change_forum(%Forum{})
    render(conn, "new.html", title: "New Forum", changeset: changeset)
  end

  def create(conn, %{"forum" => forum_params}) do
    case Forums.create_forum(forum_params) do
      {:ok, _forum} ->
        conn
        |> put_flash(:info, "Forum created successfully.")
        |> redirect(to: ~p"/admin/forums")

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    changeset = Forums.change_forum(conn.assigns.forum)
    render(conn, "edit.html", title: "Editing Forum", changeset: changeset)
  end

  def update(conn, %{"forum" => forum_params}) do
    case Forums.update_forum(conn.assigns.forum, forum_params) do
      {:ok, _forum} ->
        conn
        |> put_flash(:info, "Forum updated successfully.")
        |> redirect(to: ~p"/admin/forums")

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :edit, Forum) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
