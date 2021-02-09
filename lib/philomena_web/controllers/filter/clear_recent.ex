defmodule PhilomenaWeb.Filter.ClearRecentController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  plug PhilomenaWeb.RequireUserPlug

  def delete(conn, _params) do
    {:ok, user} = Users.clear_recent_filters(conn.assigns.current_user)

    conn
    |> put_flash(:info, "Cleared recent filters")
    |> redirect(external: conn.assigns.referrer)
  end
end
