defmodule Philomena.Native do
  use Rustler, otp_app: :philomena

  # When your NIF is loaded, it will override this function.
  def markdown_to_html(_text), do: :erlang.nif_error(:nif_not_loaded)
  def markdown_to_html_unsafe(_text), do: :erlang.nif_error(:nif_not_loaded)
end
