defmodule PhilomenaWeb.Admin.User.ActivationController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"user_id" => slug}) do
    case Users.create_user_activation(conn.assigns.actor, slug) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User was reactivated.")
        |> redirect(to: ~p"/profiles/#{user}")

      {:error, %Ecto.Changeset{data: user}} ->
        conn
        |> put_flash(:error, "User is already active.")
        |> redirect(to: ~p"/profiles/#{user}")

      error ->
        error
    end
  end

  def delete(conn, %{"user_id" => slug}) do
    case Users.delete_user_activation(conn.assigns.actor, slug) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User was deactivated.")
        |> redirect(to: ~p"/profiles/#{user}")

      {:error, %Ecto.Changeset{data: user}} ->
        conn
        |> put_flash(:error, "User is already deactivated.")
        |> redirect(to: ~p"/profiles/#{user}")

      error ->
        error
    end
  end
end
