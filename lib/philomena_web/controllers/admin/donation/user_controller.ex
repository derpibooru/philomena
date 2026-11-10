defmodule PhilomenaWeb.Admin.Donation.UserController do
  use PhilomenaWeb, :controller

  alias Philomena.Donations

  action_fallback PhilomenaWeb.FallbackController

  def show(conn, %{"id" => slug}) do
    with {:ok, {user, changeset}} <-
           Donations.show_user_donations(conn.assigns.actor, slug) do
      render(conn, "index.html",
        title: "Donations for User `#{user.name}'",
        user: user,
        donations: user.donations,
        changeset: changeset
      )
    end
  end
end
