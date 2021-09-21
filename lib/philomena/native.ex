defmodule Philomena.Native do
  use Rustler, otp_app: :philomena

  # Markdown
  def markdown_to_html(_text, _replacements), do: :erlang.nif_error(:nif_not_loaded)
  def markdown_to_html_unsafe(_text, _replacements), do: :erlang.nif_error(:nif_not_loaded)

  # Camo
  def camo_image_url(_uri), do: :erlang.nif_error(:nif_not_loaded)
end
