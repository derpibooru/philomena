defmodule PhilomenaWeb.Admin.User.AvatarController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  action_fallback PhilomenaWeb.FallbackController

  def delete(conn, %{"user_id" => slug}) do
    with {:ok, user} <- Users.delete_user_avatar(conn.assigns.actor, slug) do
      conn
      |> put_flash(:info, "Successfully removed avatar.")
      |> redirect(to: ~p"/admin/users/#{user}/edit")
    end
  end
end
