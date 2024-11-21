defmodule Philomena.Native do
  @moduledoc false

  use Rustler, otp_app: :philomena, crate: "philomena"

  @spec markdown_to_html(String.t(), %{String.t() => String.t()}) :: String.t()
  def markdown_to_html(_text, _replacements), do: :erlang.nif_error(:nif_not_loaded)

  @spec markdown_to_html_unsafe(String.t(), %{String.t() => String.t()}) :: String.t()
  def markdown_to_html_unsafe(_text, _replacements), do: :erlang.nif_error(:nif_not_loaded)

  @spec camo_image_url(String.t()) :: String.t()
  def camo_image_url(_uri), do: :erlang.nif_error(:nif_not_loaded)

  @spec zip_open_writer(Path.t()) :: {:ok, reference()} | {:error, atom()}
  def zip_open_writer(_path), do: :erlang.nif_error(:nif_not_loaded)

  @spec zip_start_file(reference(), String.t()) :: :ok | :error
  def zip_start_file(_zip, _name), do: :erlang.nif_error(:nif_not_loaded)

  @spec zip_write(reference(), binary()) :: :ok | :error
  def zip_write(_zip, _data), do: :erlang.nif_error(:nif_not_loaded)

  @spec zip_finish(reference()) :: :ok | :error
  def zip_finish(_zip), do: :erlang.nif_error(:nif_not_loaded)
end
