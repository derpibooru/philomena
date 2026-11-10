defmodule PhilomenaWeb.Registration.NameController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  action_fallback PhilomenaWeb.FallbackController

  def edit(conn, _params) do
    with {:ok, %Ecto.Changeset{} = changeset} <-
           Users.edit_name(conn.assigns.actor) do
      render(conn, "edit.html", title: "Editing Name", changeset: changeset)
    end
  end

  def update(conn, %{"user" => user_params}) do
    case Users.update_name(conn.assigns.actor, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Name successfully updated.")
        |> redirect(to: ~p"/profiles/#{user}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", changeset: changeset)

      {:error, _} = error ->
        error
    end
  end
end
