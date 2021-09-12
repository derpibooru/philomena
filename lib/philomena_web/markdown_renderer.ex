defmodule PhilomenaWeb.MarkdownRenderer do
  alias Philomena.Markdown

  def render(text, _conn) do
    Markdown.to_html(text)
  end
end
