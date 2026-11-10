defmodule PhilomenaWeb.TagView do
  use PhilomenaWeb, :view

  alias Philomena.Tags
  alias Philomena.Tags.Tag
  alias PhilomenaWeb.ImageScope

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
    Tags.quick_tag_table()
    |> render_quick_tags(conn)
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

  # This is a rendered template, so raw/1 has no effect on safety
  # sobelow_skip ["XSS.Raw"]
  defp render_quick_tags(%{tags: tags, shipping: shipping, data: data}, conn) do
    render(PhilomenaWeb.TagView, "_quick_tag_table.html",
      tags: tags,
      shipping: shipping,
      data: data,
      conn: conn
    )
    |> Phoenix.HTML.Safe.to_iodata()
    |> Phoenix.HTML.raw()
  end

  defp manages_links?(conn),
    do: can?(conn, :index, Philomena.ArtistLinks.ArtistLink)

  defp manages_dnp?(conn),
    do: can?(conn, :index, Philomena.DnpEntries.DnpEntry)

  defp tag_url_root do
    Application.get_env(:philomena, :tag_url_root)
  end
end
