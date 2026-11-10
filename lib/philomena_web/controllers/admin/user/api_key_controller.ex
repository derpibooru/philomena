defmodule PhilomenaWeb.Admin.User.ApiKeyController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  action_fallback PhilomenaWeb.FallbackController

  def delete(conn, %{"user_id" => slug}) do
    with {:ok, user} <- Users.delete_user_api_key(conn.assigns.actor, slug) do
      conn
      |> put_flash(:info, "API token successfully reset.")
      |> redirect(to: ~p"/profiles/#{user}")
    end
  end
end
