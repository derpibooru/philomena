defmodule PhilomenaWeb.CommissionController do
  use PhilomenaWeb, :controller

  alias Philomena.Textile.Renderer
  alias Philomena.Commissions.{Item, Commission}
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:new, :create, :edit, :update, :destroy]
  plug :load_and_authorize_resource, model: Commission, only: [:show], preload: [sheet_image: :tags, user: [awards: :badge], items: [example_image: :tags]]

  def index(conn, params) do
    commissions =
      commission_search(params["commission"])
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html", commissions: commissions, layout_class: "layout--wide")
  end

  def show(conn, _params) do
    commission = conn.assigns.commission

    item_descriptions =
      commission.items
      |> Enum.map(&%{body: &1.description})
      |> Renderer.render_collection()

    item_add_ons =
      commission.items
      |> Enum.map(&%{body: &1.add_ons})
      |> Renderer.render_collection()

    [information, contact, will_create, will_not_create] =
      Renderer.render_collection([
        %{body: commission.information},
        %{body: commission.contact},
        %{body: commission.will_create},
        %{body: commission.will_not_create}
      ])

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

  defp commission_search(attrs) when is_map(attrs) do
    item_type = presence(attrs["item_type"])
    categories = presence(attrs["category"])
    keywords = presence(attrs["keywords"])
    price_min = to_f(presence(attrs["price_min"]) || 0)
    price_max = to_f(presence(attrs["price_max"]) || 9999)

    query =
      commission_search(nil)
      |> where([_c, ci], ci.base_price > ^price_min and ci.base_price < ^price_max)

    query =
      if item_type do
        query
        |> where([_c, ci], ci.item_type == ^item_type)
      else
        query
      end

    query =
      if categories do
        query
        |> where([c, _ci], fragment("? @> ?", c.categories, ^categories))
      else
        query
      end

    query =
      if keywords do
        query
        |> where([c, _ci], ilike(c.information, ^like_sanitize(keywords)) or ilike(c.will_create, ^like_sanitize(keywords)))
      else
        query
      end

    query
  end

  defp commission_search(_attrs) do
    from c in Commission,
      where: c.open == true,
      where: c.commission_items_count > 0,
      inner_join: ci in Item, on: ci.commission_id == c.id,
      group_by: c.id,
      order_by: [asc: fragment("random()")],
      preload: [user: [awards: :badge], items: [example_image: :tags]]
  end

  defp presence(nil),
    do: nil
  defp presence([]),
    do: nil
  defp presence(string) when is_binary(string),
    do: if(String.trim(string) == "", do: nil, else: string)
  defp presence(object),
    do: object

  defp to_f(input) do
    case Float.parse(to_string(input)) do
      {float, _rest} -> float
      _error         -> 0.0
    end
  end

  defp like_sanitize(input) do
    "%" <> String.replace(input, ["\\", "%", "_"], &<<"\\", &1>>) <> "%"
  end
end