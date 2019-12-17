defmodule PhilomenaWeb.Admin.Donation.UserController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Donations.Donation
  alias Philomena.Donations

  plug :verify_authorized
  plug :load_resource, model: User, id_field: "slug", persisted: true, preload: [donations: :user]

  def show(conn, _params) do
    user = conn.assigns.user
    changeset = Donations.change_donation(%Donation{})
    render(conn, "index.html", title: "Donations for User `#{user.name}'", donations: user.donations, changeset: changeset)
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, Donation) do
      true   -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
