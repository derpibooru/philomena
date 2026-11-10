defmodule Philomena.Markdown do
  @markdown_chars ~r/[\*_\[\]\(\)\^`\%\\~<>#\|]/

  @doc """
  Converts user-input Markdown to HTML, with the specified map of image
  replacements (which converts ">>1234p" syntax to an embedded image).
  """
  @spec to_html(String.t(), %{String.t() => String.t()}) :: String.t()
  def to_html(text, replacements), do: Philomena.Native.markdown_to_html(text, replacements)

  @doc """
  Converts trusted-input Markdown to HTML, with the specified map of image
  replacements (which converts ">>1234p" syntax to an embedded image). This
  function does not strip any raw HTML embedded in the document.
  """
  @spec to_html_unsafe(String.t(), %{String.t() => String.t()}) :: String.t()
  def to_html_unsafe(text, replacements),
    do: Philomena.Native.markdown_to_html_unsafe(text, replacements)

  @doc """
  Renders a line-by-line diff between two Markdown sources as an HTML table.
  Each line becomes a row with old/new line-number gutters, changed lines get
  word-level `<del class="diff__hl">` / `<ins class="diff__hl">` highlights,
  and long unchanged runs collapse into "N unchanged lines" separator rows.
  The source text is HTML-escaped during rendering, so the output is safe.
  """
  @spec to_html_diff(String.t(), String.t()) :: String.t()
  def to_html_diff(old, new),
    do: Philomena.Native.markdown_diff_to_html(old, new)

  @doc """
  Escapes special characters in text which is to be rendered as Markdown.
  """
  @spec escape(String.t()) :: String.t()
  def escape(text) do
    @markdown_chars
    |> Regex.replace(text, fn m ->
      "\\#{m}"
    end)
  end
end
