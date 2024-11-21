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
  Places a Markdown document into its canonical CommonMark form.
  """
  @spec to_cm(String.t()) :: String.t()
  def to_cm(text),
    do: Philomena.Native.markdown_to_cm(text)

  @doc """
  Determines whether a Markdown document uses a subscript operator, for migration.
  """
  @spec has_subscript?(String.t()) :: boolean()
  def has_subscript?(text),
    do: Philomena.Native.markdown_has_subscript(text)

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
