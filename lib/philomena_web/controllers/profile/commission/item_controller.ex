defmodule PhilomenaWeb.Profile.Commission.ItemController do
  use PhilomenaWeb, :controller

  alias Philomena.Commissions

  action_fallback PhilomenaWeb.FallbackController

  def new(conn, %{"profile_id" => slug}) do
    with {:ok, %Ecto.Changeset{data: item} = changeset} <-
           Commissions.new_item(conn.assigns.actor, slug) do
      render(conn, "new.html",
        title: "New Commission Item",
        user: item.commission.user,
        commission: item.commission,
        changeset: changeset
      )
    end
  end

  def create(conn, %{"profile_id" => slug, "item" => item_params}) do
    case Commissions.create_item(conn.assigns.actor, slug, item_params) do
      {:ok, item} ->
        conn
        |> put_flash(:info, "Item successfully created.")
        |> redirect(to: ~p"/profiles/#{item.commission.user}/commission")

      {:error, %Ecto.Changeset{data: item} = changeset} ->
        render(conn, "new.html",
          user: item.commission.user,
          commission: item.commission,
          changeset: changeset
        )

      error ->
        error
    end
  end

  def edit(conn, %{"profile_id" => slug, "id" => id}) do
    with {:ok, %Ecto.Changeset{data: item} = changeset} <-
           Commissions.edit_item(conn.assigns.actor, slug, id) do
      render(conn, "edit.html",
        title: "Editing Commission Item",
        user: item.commission.user,
        commission: item.commission,
        item: item,
        changeset: changeset
      )
    end
  end

  def update(conn, %{"profile_id" => slug, "id" => id, "item" => item_params}) do
    case Commissions.update_item(conn.assigns.actor, slug, id, item_params) do
      {:ok, item} ->
        conn
        |> put_flash(:info, "Item successfully updated.")
        |> redirect(to: ~p"/profiles/#{item.commission.user}/commission")

      {:error, %Ecto.Changeset{data: item} = changeset} ->
        render(conn, "edit.html",
          user: item.commission.user,
          commission: item.commission,
          item: item,
          changeset: changeset
        )

      error ->
        error
    end
  end

  def delete(conn, %{"profile_id" => slug, "id" => id}) do
    with {:ok, item} <- Commissions.delete_item(conn.assigns.actor, slug, id) do
      conn
      |> put_flash(:info, "Item deleted successfully.")
      |> redirect(to: ~p"/profiles/#{item.commission.user}/commission")
    end
  end
end
