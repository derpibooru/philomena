defmodule PhilomenaWeb.Tag.WatchController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags.Tag
  alias Philomena.Users
  alias Philomena.Repo

  plug :load_tag

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

  def load_tag(conn, _opts) do
    tag = Repo.get_by!(Tag, slug: URI.encode(conn.params["tag_id"]))

    assign(conn, :tag, tag)
  end
end