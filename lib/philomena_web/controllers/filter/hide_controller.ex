defmodule PhilomenaWeb.Filter.HideController do
  use PhilomenaWeb, :controller

  alias Philomena.Filters

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    render_result(
      conn,
      Filters.create_filter_hide(actor(conn), current_filter(conn), params["tag"])
    )
  end

  def delete(conn, params) do
    render_result(
      conn,
      Filters.delete_filter_hide(actor(conn), current_filter(conn), params["tag"])
    )
  end

  defp actor(conn), do: conn.assigns.actor
  defp current_filter(conn), do: conn.assigns.current_filter

  # A denied filter edit is answered with an empty 403 and an update failure with
  # an empty 500; the ban and not-found shapes redirect through the fallback.
  defp render_result(conn, result) do
    case result do
      {:ok, _filter} ->
        conn |> put_status(:ok) |> text("")

      {:error, :unauthorized} ->
        conn |> put_status(:forbidden) |> text("")

      {:error, %Ecto.Changeset{}} ->
        conn |> put_status(:internal_server_error) |> text("")

      {:error, _} = error ->
        error
    end
  end
end
