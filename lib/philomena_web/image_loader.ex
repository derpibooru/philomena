defmodule PhilomenaWeb.ImageLoader do
  alias Philomena.Images.{Image, Query}
  alias Philomena.Textile.Renderer
  alias Philomena.Tags.Tag
  alias Philomena.Repo
  import Ecto.Query

  def search_string(conn, search_string, options \\ []) do
    user = conn.assigns.current_user

    with {:ok, tree} <- Query.compile(user, search_string) do
      {:ok, query(conn, tree, options)}
    else
      error ->
        error
    end
  end

  def query(conn, body, options \\ []) do
    sort_queries = Keyword.get(options, :queries, [])
    sort_sorts   = Keyword.get(options, :sorts, [%{created_at: :desc}])
    pagination   = Keyword.get(options, :pagination, conn.assigns.image_pagination)
    queryable    = Keyword.get(options, :queryable, Image |> preload(:tags))

    user    = conn.assigns.current_user
    filter  = conn.assigns.compiled_filter
    filters = create_filters(user, filter)

    records =
      Image.search_records(
        %{
          query: %{
            bool: %{
              must: List.flatten([body, sort_queries]),
              must_not: filters
            }
          },
          sort: sort_sorts
        },
        pagination,
        queryable
      )

    tags =
      body
      |> search_tag_names()
      |> load_tags()
      |> render_bodies(conn)

    {records, tags}
  end

  defp create_filters(user, filter) do
    [
      filter,
      %{term: %{hidden_from_users: true}}
    ]
    |> maybe_custom_hide(user)
  end

  defp maybe_custom_hide(filters, %{id: id}),
    do: [%{term: %{hidden_by_user_ids: id}} | filters]

  defp maybe_custom_hide(filters, _user),
    do: filters

  # TODO: the search parser should try to optimize queries
  defp search_tag_name(%{term: %{"namespaced_tags.name" => tag_name}}), do: [tag_name]
  defp search_tag_name(_other_query), do: []

  defp search_tag_names(%{bool: %{must: musts}}), do: Enum.flat_map(musts, &search_tag_name(&1))
  defp search_tag_names(%{bool: %{should: shoulds}}), do: Enum.flat_map(shoulds, &search_tag_name(&1))
  defp search_tag_names(%{term: %{"namespaced_tags.name" => tag_name}}), do: [tag_name]
  defp search_tag_names(_other_query), do: []

  defp load_tags([]), do: []
  defp load_tags(tags) do
    Tag
    |> join(:left, [t], at in Tag, on: t.id == at.aliased_tag_id)
    |> where([t, at], t.name in ^tags or at.name in ^tags)
    |> preload([:aliases, :implied_tags, :implied_by_tags, :dnp_entries, public_links: :user])
    |> Repo.all()
  end

  defp render_bodies([], _conn), do: []
  defp render_bodies([tag], conn) do
    dnp_bodies =
      Renderer.render_collection(Enum.map(tag.dnp_entries, &%{body: &1.conditions || ""}), conn)

    dnp_entries =
      Enum.zip(dnp_bodies, tag.dnp_entries)

    description =
      Renderer.render_one(%{body: tag.description || ""})

    [{tag, description, dnp_entries}]
  end
  defp render_bodies(tags, _conn), do: tags
end