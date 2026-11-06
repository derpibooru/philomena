defmodule PhilomenaWeb.DeactivationController do
  use PhilomenaWeb, :controller
  alias PhilomenaWeb.UserAuth
  alias Philomena.Users

  action_fallback PhilomenaWeb.FallbackController

  def show(conn, _params) do
    render(conn, "index.html", title: "Deactivate Account")
  end

  def delete(conn, _params) do
    with {:ok, _user} <-
           Users.delete_deactivation(conn.assigns.actor, &url(~p"/reactivations/#{&1}")) do
      UserAuth.log_out_user(conn)
    end
  end
end
