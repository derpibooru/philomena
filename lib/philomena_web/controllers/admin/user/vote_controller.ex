defmodule PhilomenaWeb.Admin.User.VoteController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  action_fallback PhilomenaWeb.FallbackController

  def delete(conn, %{"user_id" => slug}) do
    with {:ok, user} <- Users.delete_user_votes(conn.assigns.actor, slug) do
      conn
      |> put_flash(:info, "Vote and fave wipe started.")
      |> redirect(to: ~p"/profiles/#{user}")
    end
  end
end
