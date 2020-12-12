defmodule PhilomenaWeb.CommissionController do
  use PhilomenaWeb, :controller

  alias Philomena.Commissions.{Item, Commission}
  alias Philomena.UserIps.UserIp
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.MapParameterPlug, [param: "commission"] when action in [:index]
  plug :preload_commission

  def index(conn, params) do
    commissions =
      commission_search(params["commission"])
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Commissions",
      commissions: commissions,
      layout_class: "layout--wide"
    )
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
        |> where(
          [c, _ci],
          ilike(c.information, ^like_sanitize(keywords)) or
            ilike(c.will_create, ^like_sanitize(keywords))
        )
      else
        query
      end

    query
  end

  defp commission_search(_attrs) do
    from c in Commission,
      where: c.open == true,
      where: c.commission_items_count > 0,
      inner_join: ci in Item,
      on: ci.commission_id == c.id,
      inner_join: ui in UserIp,
      on: ui.user_id == c.user_id,
      where: ui.updated_at >= ago(2, "week"),
      group_by: c.id,
      order_by: [asc: fragment("random()")],
      preload: [user: [awards: :badge], items: [example_image: [tags: :aliases]]]
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
      _error -> 0.0
    end
  end

  defp like_sanitize(input) do
    "%" <> String.replace(input, ["\\", "%", "_"], &<<"\\", &1>>) <> "%"
  end

  defp preload_commission(conn, _opts) do
    user = conn.assigns.current_user

    case user do
      nil ->
        conn

      user ->
        user = Repo.preload(user, :commission)

        assign(conn, :current_user, user)
    end
  end
end
