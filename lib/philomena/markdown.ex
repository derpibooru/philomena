defmodule Philomena.Markdown do
  @markdown_chars ~r/[\*_\[\]\(\)\^`\%\\~<>#\|]/

  # When your NIF is loaded, it will override this function.
  def to_html(text), do: Philomena.Native.markdown_to_html(text)
  def to_html_unsafe(text), do: Philomena.Native.markdown_to_html_unsafe(text)

  def escape_markdown(text) do
    @markdown_chars
    |> Regex.replace(text, fn m ->
      "\\#{m}"
    end)
  end
end
