defmodule PhilomenaWeb.Filter.ClearRecentController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  action_fallback PhilomenaWeb.FallbackController

  def delete(conn, _params) do
    with {:ok, _user} <- Users.delete_recent_filters(conn.assigns.actor) do
      conn
      |> put_flash(:info, "Cleared recent filters.")
      |> redirect(to: ~p"/filters")
    end
  end
end
