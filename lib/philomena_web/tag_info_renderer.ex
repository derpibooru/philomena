defmodule PhilomenaWeb.TagInfoRenderer do
  @moduledoc """
  Renders the tag info shown next to image listings.

  When a search names exactly one tag, its description and DNP conditions
  are rendered to HTML for the sidebar; each tag becomes a
  `{tag, description, dnp_entries}` tuple, with `dnp_entries` pairing each
  rendered body with its entry. Any other tag list passes through unchanged.
  """

  alias PhilomenaWeb.MarkdownRenderer

  def render_tag_info([tag], conn) do
    dnp_bodies =
      MarkdownRenderer.render_collection(
        Enum.map(tag.dnp_entries, &%{body: &1.conditions || ""}),
        conn
      )

    dnp_entries = Enum.zip(dnp_bodies, tag.dnp_entries)

    description = MarkdownRenderer.render_one(%{body: tag.description || ""}, conn)

    [{tag, description, dnp_entries}]
  end

  def render_tag_info(tags, _conn), do: tags
end
