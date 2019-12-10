defmodule PhilomenaWeb.Admin.UserLink.ContactController do
  use PhilomenaWeb, :controller

  alias Philomena.UserLinks.UserLink
  alias Philomena.UserLinks

  plug PhilomenaWeb.CanaryMapPlug, create: :edit
  plug :load_and_authorize_resource, model: UserLink, id_name: "user_link_id", persisted: true, preload: [:user]

  def create(conn, _params) do
    {:ok, user_link} = UserLinks.contact_user_link(conn.assigns.user_link, conn.assigns.current_user)

    conn
    |> put_flash(:info, "User link successfully marked as contacted.")
    |> redirect(to: Routes.profile_user_link_path(conn, :show, conn.assigns.user_link.user, user_link))
  end
end