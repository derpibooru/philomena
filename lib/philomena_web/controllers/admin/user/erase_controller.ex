defmodule PhilomenaWeb.Admin.User.EraseController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  action_fallback PhilomenaWeb.FallbackController

  def new(conn, %{"user_id" => slug}) do
    case Users.new_user_erase(conn.assigns.actor, slug) do
      {:ok, user} ->
        render(conn, "new.html", title: "Erase user", user: user)

      error ->
        render_erase_error(conn, error)
    end
  end

  def create(conn, %{"user_id" => slug}) do
    case Users.create_user_erase(conn.assigns.actor, slug) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User erase started")
        |> redirect(to: ~p"/profiles/#{user}")

      error ->
        render_erase_error(conn, error)
    end
  end

  defp render_erase_error(conn, error) do
    case error do
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Couldn't find that username. Was it already erased?")
        |> redirect(to: ~p"/admin/users")

      {:error, {:privileged, user}} ->
        conn
        |> put_flash(:error, "Cannot erase a privileged user")
        |> redirect(to: ~p"/profiles/#{user}")

      {:error, {:verified, user}} ->
        conn
        |> put_flash(:error, "Cannot erase a verified user")
        |> redirect(to: ~p"/profiles/#{user}")

      {:error, %Ecto.Changeset{data: user}} ->
        conn
        |> put_flash(:error, "Failed to erase user")
        |> redirect(to: ~p"/profiles/#{user}")

      error ->
        error
    end
  end
end
