defmodule PhilomenaWeb.TextRenderer do
  alias PhilomenaWeb.MarkdownRenderer

  def render_one(item, conn) do
    hd(render_collection([item], conn))
  end

  def render_collection(items, conn) do
    Enum.map(items, fn item ->
      MarkdownRenderer.render(item.body, conn)
    end)
  end
end
