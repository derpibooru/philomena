defmodule PhilomenaWeb.TextRenderer do
  alias PhilomenaWeb.TextileRenderer
  alias PhilomenaWeb.MarkdownRenderer

  def render_one(item, conn) do
    hd(render_collection([item], conn))
  end

  def render_collection(items, conn) do
    Enum.map(items, fn item ->
      if Map.has_key?(item, :body_md) && item.body_md != nil && item.body_md != "" do
        MarkdownRenderer.render(item.body_md, conn)
      else
        TextileRenderer.render(item.body, conn)
      end
    end)
  end
end
