defmodule PhilomenaWeb.Profile.ScratchpadController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Users

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.CanaryMapPlug, edit: :index, update: :index
  plug :load_resource, model: User, id_name: "profile_id", id_field: "slug", persisted: true

  def edit(conn, _params) do
    changeset = Users.change_user(conn.assigns.user)

    render(conn, "edit.html",
      title: "Editing Moderation Scratchpad",
      changeset: changeset,
      user: conn.assigns.user
    )
  end

  def update(conn, %{"user" => user_params}) do
    user = conn.assigns.user

    case Users.update_scratchpad(user, user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Moderation scratchpad successfully updated.")
        |> redirect(to: Routes.profile_path(conn, :show, user))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end
end
