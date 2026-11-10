defmodule PhilomenaWeb.Admin.Badge.UserController do
  use PhilomenaWeb, :controller

  alias Philomena.Badges

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"badge_id" => id}) do
    with {:ok, {badge, users}} <-
           Badges.list_badge_users(conn.assigns.actor, id, conn.assigns.scrivener) do
      render(conn, "index.html",
        title: "Users with badge #{badge.title}",
        badge: badge,
        users: users
      )
    end
  end
end
