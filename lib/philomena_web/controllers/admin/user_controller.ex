defmodule PhilomenaWeb.Admin.UserController do
  use PhilomenaWeb, :controller

  alias Philomena.Users
  alias Philomena.Users.AdminUserForm

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    case Users.query_users(conn.assigns.actor, query_param(params, "uq"), conn.assigns.pagination) do
      {:ok, users, changeset} ->
        render(conn, "index.html",
          title: "Admin - Users",
          layout_class: "layout--medium",
          users: users,
          changeset: changeset
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "index.html",
          title: "Admin - Users",
          layout_class: "layout--medium",
          users: nil,
          changeset: changeset
        )

      error ->
        error
    end
  end

  def edit(conn, %{"id" => slug}) do
    with {:ok, %AdminUserForm{} = form} <-
           Users.edit_user(conn.assigns.actor, slug) do
      render(conn, "edit.html",
        title: "Editing User",
        user: form.changeset.data,
        changeset: form.changeset,
        roles: form.roles
      )
    end
  end

  def update(conn, %{"id" => slug, "user" => user_params}) do
    with {:ok, user} <- Users.update_user(conn.assigns.actor, slug, user_params) do
      conn
      |> put_flash(:info, "User successfully updated.")
      |> redirect(to: ~p"/profiles/#{user}")
    else
      {:error, %AdminUserForm{} = form} ->
        render(conn, "edit.html",
          user: form.changeset.data,
          changeset: form.changeset,
          roles: form.roles
        )

      error ->
        error
    end
  end
end
