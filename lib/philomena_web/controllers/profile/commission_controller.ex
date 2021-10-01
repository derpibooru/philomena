defmodule PhilomenaWeb.Profile.CommissionController do
  use PhilomenaWeb, :controller

  alias Philomena.Commissions.Commission
  alias Philomena.Commissions
  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.Users.User

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create, :edit, :update, :delete]

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

  plug :ensure_commission when action in [:show, :edit, :update, :delete]
  plug :ensure_no_commission when action in [:new, :create]
  plug :ensure_correct_user when action in [:new, :create, :edit, :update, :delete]
  plug :ensure_links_verified when action in [:new, :create, :edit, :update, :delete]

  def show(conn, _params) do
    commission = conn.assigns.user.commission

    items =
      commission.items
      |> Enum.sort(&(Decimal.compare(&1.base_price, &2.base_price) != :gt))

    item_descriptions =
      items
      |> Enum.map(&%{body: &1.description})
      |> MarkdownRenderer.render_collection(conn)

    item_add_ons =
      items
      |> Enum.map(&%{body: &1.add_ons})
      |> MarkdownRenderer.render_collection(conn)

    [information, contact, will_create, will_not_create] =
      MarkdownRenderer.render_collection(
        [
          %{body: commission.information || ""},
          %{body: commission.contact || ""},
          %{body: commission.will_create || ""},
          %{body: commission.will_not_create || ""}
        ],
        conn
      )

    rendered = %{
      information: information,
      contact: contact,
      will_create: will_create,
      will_not_create: will_not_create
    }

    items = Enum.zip([item_descriptions, item_add_ons, items])

    render(conn, "show.html",
      title: "Showing Commission",
      rendered: rendered,
      commission: commission,
      items: items,
      layout_class: "layout--wide"
    )
  end

  def new(conn, _params) do
    changeset = Commissions.change_commission(%Commission{})
    render(conn, "new.html", title: "New Commission", changeset: changeset)
  end

  def create(conn, %{"commission" => commission_params}) do
    user = conn.assigns.current_user

    case Commissions.create_commission(user, commission_params) do
      {:ok, _commission} ->
        conn
        |> put_flash(:info, "Commission successfully created.")
        |> redirect(to: Routes.profile_commission_path(conn, :show, user))

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    changeset = Commissions.change_commission(conn.assigns.user.commission)
    render(conn, "edit.html", title: "Editing Commission", changeset: changeset)
  end

  def update(conn, %{"commission" => commission_params}) do
    commission = conn.assigns.user.commission

    case Commissions.update_commission(commission, commission_params) do
      {:ok, _commission} ->
        conn
        |> put_flash(:info, "Commission successfully updated.")
        |> redirect(to: Routes.profile_commission_path(conn, :show, conn.assigns.user))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    commission = conn.assigns.user.commission

    {:ok, _commission} = Commissions.delete_commission(commission)

    conn
    |> put_flash(:info, "Commission deleted successfully.")
    |> redirect(to: Routes.commission_path(conn, :index))
  end

  defp ensure_commission(conn, _opts) do
    case is_nil(conn.assigns.user.commission) do
      true -> PhilomenaWeb.NotFoundPlug.call(conn)
      false -> conn
    end
  end

  defp ensure_no_commission(conn, _opts) do
    case is_nil(conn.assigns.user.commission) do
      false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
      true -> conn
    end
  end

  defp ensure_correct_user(conn, _opts) do
    user_id = conn.assigns.user.id

    case conn.assigns.current_user do
      %{id: ^user_id} -> conn
      %{role: role} when role in ["admin", "moderator"] -> conn
      _other -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp ensure_links_verified(conn, _opts) do
    case Enum.any?(conn.assigns.user.verified_links) do
      true ->
        conn

      false ->
        conn
        |> put_flash(
          :error,
          "You must have a verified artist link to create a commission listing."
        )
        |> redirect(to: Routes.commission_path(conn, :index))
        |> halt()
    end
  end
end
