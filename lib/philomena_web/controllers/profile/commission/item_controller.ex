defmodule PhilomenaWeb.Profile.Commission.ItemController do
  use PhilomenaWeb, :controller

  alias Philomena.Commissions.Item
  alias Philomena.Commissions
  alias Philomena.Users.User
  alias Philomena.Repo

  plug PhilomenaWeb.FilterBannedUsersPlug

  plug :load_resource,
    model: User,
    id_name: "profile_id",
    id_field: "slug",
    preload: [
      :verified_links,
      commission: [
        sheet_image: [tags: :aliases],
        user: [awards: :badge],
        items: [example_image: [tags: :aliases]]
      ]
    ],
    persisted: true

  plug :ensure_commission
  plug :ensure_correct_user

  def new(conn, _params) do
    user = conn.assigns.user
    commission = user.commission

    changeset = Commissions.change_item(%Item{})

    render(conn, "new.html",
      title: "New Commission Item",
      user: user,
      commission: commission,
      changeset: changeset
    )
  end

  def create(conn, %{"item" => item_params}) do
    user = conn.assigns.user
    commission = user.commission

    case Commissions.create_item(commission, item_params) do
      {:ok, _multi} ->
        conn
        |> put_flash(:info, "Item successfully created.")
        |> redirect(to: Routes.profile_commission_path(conn, :show, conn.assigns.user))

      {:error, changeset} ->
        render(conn, "new.html", user: user, commission: commission, changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id}) do
    user = conn.assigns.user
    commission = user.commission
    item = Repo.get_by!(Item, commission_id: commission.id, id: id)

    changeset = Commissions.change_item(item)

    render(conn, "edit.html",
      title: "Editing Commission Item",
      user: user,
      commission: commission,
      item: item,
      changeset: changeset
    )
  end

  def update(conn, %{"id" => id, "item" => item_params}) do
    user = conn.assigns.user
    commission = user.commission
    item = Repo.get_by!(Item, commission_id: commission.id, id: id)

    case Commissions.update_item(item, item_params) do
      {:ok, _commission} ->
        conn
        |> put_flash(:info, "Item successfully updated.")
        |> redirect(to: Routes.profile_commission_path(conn, :show, conn.assigns.user))

      {:error, changeset} ->
        render(conn, "edit.html",
          user: user,
          commission: commission,
          item: item,
          changeset: changeset
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.user
    commission = user.commission
    item = Repo.get_by!(Item, commission_id: commission.id, id: id)

    {:ok, _multi} = Commissions.delete_item(item)

    conn
    |> put_flash(:info, "Item deleted successfully.")
    |> redirect(to: Routes.profile_commission_path(conn, :show, conn.assigns.user))
  end

  defp ensure_commission(conn, _opts) do
    case is_nil(conn.assigns.user.commission) do
      true -> PhilomenaWeb.NotFoundPlug.call(conn)
      false -> conn
    end
  end

  defp ensure_correct_user(conn, _opts) do
    user_id = conn.assigns.user.id

    case conn.assigns.current_user do
      %{id: ^user_id} -> conn
      _other -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
