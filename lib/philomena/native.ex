defmodule Philomena.Native do
  @moduledoc false

  use Rustler, otp_app: :philomena

  @spec markdown_to_html(String.t(), %{String.t() => String.t()}) :: String.t()
  def markdown_to_html(_text, _replacements), do: :erlang.nif_error(:nif_not_loaded)

  @spec markdown_to_html_unsafe(String.t(), %{String.t() => String.t()}) :: String.t()
  def markdown_to_html_unsafe(_text, _replacements), do: :erlang.nif_error(:nif_not_loaded)

  @spec camo_image_url(String.t()) :: String.t()
  def camo_image_url(_uri), do: :erlang.nif_error(:nif_not_loaded)
end
