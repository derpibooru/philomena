defmodule PhilomenaWeb.Tag.WatchController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags.Tag
  alias Philomena.Users

  plug :load_resource, model: Tag, id_field: "slug", id_name: "tag_id", persisted: true

  def create(conn, _params) do
    case Users.watch_tag(conn.assigns.current_user, conn.assigns.tag) do
      {:ok, _user} ->
        conn
        |> put_status(:ok)
        |> text("")

      {:error, _changeset} ->
        conn
        |> put_status(:internal_server_error)
        |> text("")
    end
  end

  def delete(conn, _params) do
    case Users.unwatch_tag(conn.assigns.current_user, conn.assigns.tag) do
      {:ok, _user} ->
        conn
        |> put_status(:ok)
        |> text("")

      {:error, _changeset} ->
        conn
        |> put_status(:internal_server_error)
        |> text("")
    end
  end
end
