defmodule PhilomenaWeb.Tag.WatchController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    case Tags.create_tag_watch(conn.assigns.actor, params["tag_id"]) do
      {:ok, _user} ->
        conn
        |> put_status(:ok)
        |> text("")

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_status(:internal_server_error)
        |> text("")

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, params) do
    case Tags.delete_tag_watch(conn.assigns.actor, params["tag_id"]) do
      {:ok, _user} ->
        conn
        |> put_status(:ok)
        |> text("")

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_status(:internal_server_error)
        |> text("")

      {:error, _} = error ->
        error
    end
  end
end
