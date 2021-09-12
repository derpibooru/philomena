defmodule Philomena.Markdown do
  use Rustler, otp_app: :philomena

  @markdown_chars ~r/[\*_\[\]\(\)\^`\%\\~<>#\|]/

  # When your NIF is loaded, it will override this function.
  def to_html(_text), do: :erlang.nif_error(:nif_not_loaded)
  def to_html_unsafe(_text), do: :erlang.nif_error(:nif_not_loaded)

  def escape_markdown(text) do
    @markdown_chars
    |> Regex.replace(text, fn m ->
      "\\#{m}"
    end)
  end
end
