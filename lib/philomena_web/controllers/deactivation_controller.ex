defmodule PhilomenaWeb.DeactivationController do
  use PhilomenaWeb, :controller
  alias PhilomenaWeb.UserAuth
  alias Philomena.Users

  action_fallback PhilomenaWeb.FallbackController

  def show(conn, _params) do
    render(conn, "index.html", title: "Deactivate Account")
  end

  def delete(conn, _params) do
    case Users.delete_deactivation(conn.assigns.actor, &url(~p"/reactivations/#{&1}")) do
      {:ok, _user} ->
        UserAuth.log_out_user(conn)

      # A double submit finds the account already deactivated.
      {:error, %Ecto.Changeset{}} ->
        UserAuth.log_out_user(conn)

      error ->
        error
    end
  end
end
