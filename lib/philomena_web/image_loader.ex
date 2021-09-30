defmodule PhilomenaWeb.ImageLoader do
  alias PhilomenaWeb.ImageSorter
  alias Philomena.Elasticsearch
  alias Philomena.Images.{Image, Query}
  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.Tags.Tag
  alias Philomena.Repo
  import Ecto.Query

  # sobelow_skip ["SQL.Query"]
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
    pagination = Keyword.get(options, :pagination, conn.assigns.image_pagination)
    sorts = Keyword.get(options, :sorts, &ImageSorter.parse_sort(conn.params, &1))

    tags =
      body
      |> search_tag_names()
      |> load_tags()
      |> render_bodies(conn)

    user = conn.assigns.current_user
    filter = conn.assigns.compiled_filter
    filters = create_filters(conn, user, filter)

    %{query: query, sorts: sort} = sorts.(body)

    definition =
      Elasticsearch.search_definition(
        Image,
        %{
          query: %{
            bool: %{
              must: query,
              must_not: filters
            }
          },
          sort: sort
        },
        pagination
      )

    {definition, tags}
  end

  defp create_filters(conn, user, filter) do
    show_hidden? = Canada.Can.can?(user, :hide, %Image{})
    del = conn.params["del"]
    hidden = conn.params["hidden"]

    [
      filter
    ]
    |> maybe_show_deleted(show_hidden?, del)
    |> maybe_custom_hide(user, hidden)
  end

  # Allow moderators to index hidden images

  defp maybe_show_deleted(filters, _show_hidden?, "1"),
    do: filters

  defp maybe_show_deleted(filters, false, _param),
    do: [%{term: %{hidden_from_users: true}} | filters]

  defp maybe_show_deleted(filters, true, "only"),
    do: [%{term: %{hidden_from_users: false}} | filters]

  defp maybe_show_deleted(filters, true, "deleted"),
    do: [%{term: %{hidden_from_users: false}}, %{exists: %{field: :duplicate_id}} | filters]

  defp maybe_show_deleted(filters, true, _param),
    do: [%{term: %{hidden_from_users: true}} | filters]

  # Allow users to reverse the effect of hiding images,
  # if desired

  defp maybe_custom_hide(filters, %{id: _id}, "1"),
    do: filters

  defp maybe_custom_hide(filters, %{id: id}, _param),
    do: [%{term: %{hidden_by_user_ids: id}} | filters]

  defp maybe_custom_hide(filters, _user, _param),
    do: filters

  # TODO: the search parser should try to optimize queries
  defp search_tag_name(%{term: %{"namespaced_tags.name" => tag_name}}), do: [tag_name]
  defp search_tag_name(_other_query), do: []

  defp search_tag_names(%{bool: %{must: musts}}), do: Enum.flat_map(musts, &search_tag_name(&1))

  defp search_tag_names(%{bool: %{should: shoulds}}),
    do: Enum.flat_map(shoulds, &search_tag_name(&1))

  defp search_tag_names(%{term: %{"namespaced_tags.name" => tag_name}}), do: [tag_name]
  defp search_tag_names(_other_query), do: []

  defp load_tags([]), do: []

  defp load_tags(tags) do
    Tag
    |> join(:left, [t], at in Tag, on: t.id == at.aliased_tag_id)
    |> where([t, at], t.name in ^tags or at.name in ^tags)
    |> preload([
      :aliases,
      :aliased_tag,
      :implied_tags,
      :implied_by_tags,
      :dnp_entries,
      :channels,
      public_links: :user,
      hidden_links: :user
    ])
    |> Repo.all()
    |> Enum.uniq_by(& &1.id)
    |> Enum.filter(&is_nil(&1.aliased_tag))
    |> Tag.display_order()
  end

  defp render_bodies([], _conn), do: []

  defp render_bodies([tag], conn) do
    dnp_bodies =
      MarkdownRenderer.render_collection(
        Enum.map(tag.dnp_entries, &%{body: &1.conditions || ""}),
        conn
      )

    dnp_entries = Enum.zip(dnp_bodies, tag.dnp_entries)

    description = MarkdownRenderer.render_one(%{body: tag.description || ""}, conn)

    [{tag, description, dnp_entries}]
  end

  defp render_bodies(tags, _conn), do: tags
end
