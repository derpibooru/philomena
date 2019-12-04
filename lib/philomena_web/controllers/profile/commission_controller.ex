defmodule PhilomenaWeb.Profile.CommissionController do
  use PhilomenaWeb, :controller

  alias Philomena.Textile.Renderer
  alias Philomena.Users.User

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create, :edit, :update, :delete]
  plug :load_resource, model: User, id_name: "profile_id", id_field: "slug", preload: [commission: [sheet_image: :tags, user: [awards: :badge], items: [example_image: :tags]]], persisted: true
  plug :ensure_commission

  def show(conn, _params) do
    commission = conn.assigns.user.commission

    item_descriptions =
      commission.items
      |> Enum.map(&%{body: &1.description})
      |> Renderer.render_collection(conn)

    item_add_ons =
      commission.items
      |> Enum.map(&%{body: &1.add_ons})
      |> Renderer.render_collection(conn)

    [information, contact, will_create, will_not_create] =
      Renderer.render_collection(
        [
          %{body: commission.information},
          %{body: commission.contact},
          %{body: commission.will_create},
          %{body: commission.will_not_create}
        ],
        conn
      )

    rendered =
      %{
        information: information,
        contact: contact,
        will_create: will_create,
        will_not_create: will_not_create
      }

    items = Enum.zip([item_descriptions, item_add_ons, commission.items])

    render(conn, "show.html", rendered: rendered, commission: conn.assigns.commission, items: items, layout_class: "layout--wide")
  end

  defp ensure_commission(conn, _opts) do
    case is_nil(conn.assigns.user.commission) do
      true  -> PhilomenaWeb.NotFoundPlug.call(conn)
      false -> conn
    end
  end
end