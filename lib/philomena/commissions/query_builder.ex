defmodule Philomena.Commissions.QueryBuilder do
  @moduledoc false

  alias Philomena.Commissions.Commission
  alias Philomena.Commissions.Item
  alias Philomena.Commissions.SearchQuery
  alias Philomena.UserIps.UserIp
  import Ecto.Query

  @doc """
  Searches commissions based on the given parameters.

  ## Parameters

    * params - Map of optional search parameters:
      * item_type - Filter by item type
      * category - Filter by category
      * keywords - Search in information and will_create fields
      * price_min - Minimum base price
      * price_max - Maximum base price

  Returns `{:ok, query}` with a queryable that can be used with Repo.paginate/2,
  or `{:error, changeset}` if the provided parameters are invalid.
  """
  def search_commissions(params \\ %{}) do
    %SearchQuery{}
    |> SearchQuery.changeset(params)
    |> Ecto.Changeset.apply_action(:create)
    |> case do
      {:ok, sq} ->
        {:ok,
         commission_search_query()
         |> maybe_filter_price(sq)
         |> maybe_filter_item_type(sq)
         |> maybe_filter_categories(sq)
         |> maybe_filter_keywords(sq)}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp commission_search_query do
    # Select commissions and all of their associated items for filtering
    query =
      from c in Commission,
        as: :commission,
        where: c.open == true,
        where: c.commission_items_count > 0,
        inner_join: ci in Item,
        as: :commission_item,
        on: ci.commission_id == c.id

    # Exclude artists with no activity in the last 2 weeks
    query =
      from [commission: c] in query,
        inner_join: ui in UserIp,
        as: :user_ip,
        on: ui.user_id == c.user_id,
        where: ui.updated_at >= ago(2, "week")

    # Select the parent commissions, not the items belonging to them
    from [commission: c] in query,
      group_by: c.id,
      order_by: [asc: fragment("random()")],
      preload: [user: [awards: :badge], items: [example_image: [:sources, tags: :aliases]]]
  end

  defp maybe_filter_price(query, sq = %SearchQuery{}) do
    if not is_nil(sq.price_min) and not is_nil(sq.price_max) do
      from [commission_item: ci] in query,
        where: ci.base_price >= ^sq.price_min and ci.base_price <= ^sq.price_max
    else
      query
    end
  end

  def maybe_filter_item_type(query, sq = %SearchQuery{}) do
    if sq.item_type do
      from [commission_item: ci] in query,
        where: ci.item_type == ^sq.item_type
    else
      query
    end
  end

  defp maybe_filter_categories(query, sq = %SearchQuery{}) do
    if sq.category do
      from [commission: c] in query,
        where: fragment("? @> ?", c.categories, ^sq.category)
    else
      query
    end
  end

  defp maybe_filter_keywords(query, sq = %SearchQuery{}) do
    if sq.keywords do
      keywords = like_sanitize(sq.keywords)

      from [commission: c] in query,
        where: ilike(c.information, ^keywords) or ilike(c.will_create, ^keywords)
    else
      query
    end
  end

  defp like_sanitize(input) do
    "%" <> String.replace(input, ["\\", "%", "_"], &<<"\\", &1>>) <> "%"
  end
end
