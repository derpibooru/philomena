defmodule PhilomenaWeb.TagView do
  use PhilomenaWeb, :view

  # this is bad practice, don't copy this.
  alias Philomena.Config
  alias Philomena.Elasticsearch
  alias Philomena.Tags.Tag
  alias Philomena.Repo
  alias PhilomenaWeb.ImageScope
  import Ecto.Query

  def scope(conn), do: ImageScope.scope(conn)

  def tag_categories do
    [[key: "-", value: ""] | Tag.categories()]
  end

  def manages_tags?(conn) do
    can?(conn, :edit, %Tag{})
  end

  def aliases_tags?(conn) do
    can?(conn, :alias, %Tag{})
  end

  def pretty_tag_path(%{slug: slug}) do
    "/tags/" <> URI.encode(slug, &(&1 == ?+ or URI.char_unreserved?(&1)))
  end

  def tag_image(%{image: image}) do
    tag_url_root() <> "/" <> image
  end

  def quick_tags(conn) do
    case Application.get_env(:philomena, :quick_tags) do
      nil ->
        quick_tags =
          Config.get(:quick_tag_table)
          |> lookup_quick_tags()
          |> render_quick_tags(conn)

        Application.put_env(:philomena, :quick_tags, quick_tags)

        quick_tags

      quick_tags ->
        quick_tags
    end
  end

  def tab_class(0), do: "selected"
  def tab_class(_), do: nil

  def tab_body_class(0), do: nil
  def tab_body_class(_), do: "hidden"

  def tag_link(nil, tag_name), do: tag_name

  def tag_link(tag, tag_name) do
    title = title(implications(tag) ++ short_description(tag))

    link(tag_name, to: "#", title: title, data: [tag_name: tag_name, click_addtag: tag_name])
  end

  def tags_row_class(%{params: %{"page" => "0"}}), do: nil
  def tags_row_class(%{params: %{"page" => "1"}}), do: nil
  def tags_row_class(%{params: %{"page" => _page}}), do: "hidden"
  def tags_row_class(_conn), do: nil

  defp implications(%{implied_tags: []}), do: []

  defp implications(%{implied_tags: it}) do
    names =
      it
      |> Enum.map(& &1.name)
      |> Enum.sort()
      |> Enum.join(", ")

    ["Implies: #{names}"]
  end

  defp short_description(%{short_description: s}) when s in ["", nil], do: []
  defp short_description(%{short_description: s}), do: [s]

  defp title([]), do: nil
  defp title(descriptions), do: Enum.join(descriptions, "\n")

  defp lookup_quick_tags(%{"tabs" => tabs, "tab_modes" => tab_modes} = data) do
    tags =
      tabs
      |> Enum.flat_map(&names_in_tab(tab_modes[&1], data[&1]))
      |> tags_indexed_by_name()

    shipping =
      tabs
      |> Enum.filter(&(tab_modes[&1] == "shipping"))
      |> Map.new(fn tab ->
        sd = data[tab]

        {tab, implied_by_multitag(sd["implying"], sd["not_implying"])}
      end)

    {tags, shipping, data}
  end

  defp render_quick_tags({tags, shipping, data}, conn) do
    render(PhilomenaWeb.TagView, "_quick_tag_table.html",
      tags: tags,
      shipping: shipping,
      data: data,
      conn: conn
    )
  end

  defp names_in_tab("default", data) do
    Map.values(data)
    |> List.flatten()
  end

  defp names_in_tab("season", data) do
    Enum.map(data, fn [_number, name] -> name end)
  end

  defp names_in_tab("shorthand", data) do
    data
    |> Enum.map(fn [_title, tags] -> tags end)
    |> Enum.flat_map(&Enum.map(&1, fn [_shorthand, tag] -> tag end))
  end

  defp names_in_tab(_mode, _data), do: []

  defp tags_indexed_by_name(names) do
    Tag
    |> where([t], t.name in ^names)
    |> preload(:implied_tags)
    |> Repo.all()
    |> Map.new(&{&1.name, &1})
  end

  defp implied_by_multitag(tag_names, ignore_tag_names) do
    Tag
    |> Elasticsearch.search_definition(
      %{
        query: %{
          bool: %{
            must: Enum.map(tag_names, &%{term: %{implied_tags: &1}}),
            must_not: Enum.map(ignore_tag_names, &%{term: %{implied_tags: &1}})
          }
        },
        sort: %{images: :desc}
      },
      %{page_size: 40}
    )
    |> Elasticsearch.search_records(preload(Tag, :implied_tags))
  end

  defp manages_links?(conn),
    do: can?(conn, :index, Philomena.ArtistLinks.ArtistLink)

  defp manages_dnp?(conn),
    do: can?(conn, :index, Philomena.DnpEntries.DnpEntry)

  defp tag_url_root do
    Application.get_env(:philomena, :tag_url_root)
  end
end
