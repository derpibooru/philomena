defmodule PhilomenaWeb.Admin.User.ForceFilterController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  action_fallback PhilomenaWeb.FallbackController

  def new(conn, %{"user_id" => slug}) do
    with {:ok, %Ecto.Changeset{} = changeset} <-
           Users.new_user_force_filter(conn.assigns.actor, slug) do
      render(conn, "new.html",
        title: "Forcing filter for user",
        user: changeset.data,
        changeset: changeset
      )
    end
  end

  def create(conn, %{"user_id" => slug, "user" => user_params}) do
    case Users.create_user_force_filter(conn.assigns.actor, slug, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Filter was forced.")
        |> redirect(to: ~p"/profiles/#{user}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html",
          title: "Forcing filter for user",
          user: changeset.data,
          changeset: changeset
        )

      {:error, _reason} = error ->
        error
    end
  end

  def delete(conn, %{"user_id" => slug}) do
    with {:ok, user} <- Users.delete_user_force_filter(conn.assigns.actor, slug) do
      conn
      |> put_flash(:info, "Forced filter was removed.")
      |> redirect(to: ~p"/profiles/#{user}")
    end
  end
end
