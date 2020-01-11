defmodule PhilomenaWeb.Filter.SpoilerTypeController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  plug PhilomenaWeb.RequireUserPlug

  def update(conn, %{"user" => user_params}) do
    case Users.update_spoiler_type(conn.assigns.current_user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Changed spoiler type to #{user.spoiler_type}")
        |> redirect(external: conn.assigns.referrer)

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to set spoiler type")
        |> redirect(external: conn.assigns.referrer)
    end
  end
end
