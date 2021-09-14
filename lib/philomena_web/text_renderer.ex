defmodule PhilomenaWeb.TextRenderer do
  alias PhilomenaWeb.MarkdownRenderer
  alias PhilomenaWeb.TextileMarkdownRenderer

  def render_one(item, conn) do
    hd(render_collection([item], conn))
  end

  def render_collection(items, conn) do
    Enum.map(items, fn item ->
      if Map.has_key?(item, :body_md) && item.body_md != nil && item.body_md != "" do
        MarkdownRenderer.render(item.body_md, conn)
      else
        markdown = TextileMarkdownRenderer.render_one(item)
        MarkdownRenderer.render(markdown, conn)
      end
    end)
  end
end
