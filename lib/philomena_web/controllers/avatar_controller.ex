defmodule PhilomenaWeb.AvatarController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  plug PhilomenaWeb.ScraperPlug,
       [params_name: "user", params_key: "avatar"] when action in [:update]

  action_fallback PhilomenaWeb.FallbackController

  def edit(conn, _params) do
    with {:ok, %Ecto.Changeset{} = changeset} <-
           Users.edit_avatar(conn.assigns.actor) do
      render(conn, "edit.html", title: "Editing Avatar", changeset: changeset)
    end
  end

  def update(conn, %{"user" => user_params}) do
    upload = PhilomenaMedia.Upload.cast(user_params, "avatar")

    case Users.update_avatar(conn.assigns.actor, upload) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Successfully updated avatar.")
        |> redirect(to: ~p"/avatar/edit")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", changeset: changeset)

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, _params) do
    with {:ok, _user} <- Users.delete_avatar(conn.assigns.actor) do
      conn
      |> put_flash(:info, "Successfully removed avatar.")
      |> redirect(to: ~p"/avatar/edit")
    end
  end
end
