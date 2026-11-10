defmodule PhilomenaWeb.Admin.SubnetBanController do
  use PhilomenaWeb, :controller

  alias Philomena.Bans

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    case Bans.list_subnet_bans(conn.assigns.actor, params, conn.assigns.scrivener) do
      {:ok, subnet_bans, changeset} ->
        render(conn, "index.html",
          title: "Admin - Subnet Bans",
          layout_class: "layout--wide",
          subnet_bans: subnet_bans,
          changeset: changeset
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "index.html",
          title: "Admin - Subnet Bans",
          layout_class: "layout--wide",
          subnet_bans: nil,
          changeset: changeset
        )

      error ->
        error
    end
  end

  def new(conn, params) do
    case Bans.new_subnet_ban(conn.assigns.actor, params["specification"]) do
      {:ok, changeset} ->
        render_new(conn, changeset)

      error ->
        error
    end
  end

  defp render_new(conn, changeset) do
    render(conn, "new.html", title: "New Subnet Ban", changeset: changeset)
  end

  def create(conn, %{"subnet" => subnet_ban_params}) do
    case Bans.create_subnet_ban(conn.assigns.actor, subnet_ban_params) do
      {:ok, _subnet_ban} ->
        conn
        |> put_flash(:info, "Subnet was successfully banned.")
        |> redirect(to: ~p"/admin/subnet_bans")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      error ->
        error
    end
  end

  def edit(conn, params) do
    with {:ok, {subnet, changeset}} <-
           Bans.edit_subnet_ban(conn.assigns.actor, params["id"]) do
      render(conn, "edit.html", title: "Editing Subnet Ban", subnet: subnet, changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "subnet" => subnet_ban_params}) do
    case Bans.update_subnet_ban(conn.assigns.actor, id, subnet_ban_params) do
      {:ok, _subnet_ban} ->
        conn
        |> put_flash(:info, "Subnet ban successfully updated.")
        |> redirect(to: ~p"/admin/subnet_bans")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", subnet: changeset.data, changeset: changeset)

      error ->
        error
    end
  end

  def delete(conn, params) do
    with {:ok, _subnet_ban} <- Bans.delete_subnet_ban(conn.assigns.actor, params["id"]) do
      conn
      |> put_flash(:info, "Subnet ban successfully deleted.")
      |> redirect(to: ~p"/admin/subnet_bans")
    end
  end
end
