defmodule PhilomenaMedia.Analyzers do
  @moduledoc """
  Utilities for analyzing the format and various attributes of uploaded files.
  """

  alias PhilomenaMedia.Analyzers.{Gif, Jpeg, Png, Svg, Webm}
  alias PhilomenaMedia.Analyzers.Result
  alias PhilomenaMedia.Mime

  @doc """
  Returns an `{:ok, analyzer}` tuple, with the analyzer being a module capable
  of analyzing this media type, or `:error`.

  The allowed MIME types are:
  - `image/gif`
  - `image/jpeg`
  - `image/png`
  - `image/svg+xml`
  - `video/webm`

  > #### Info {: .info}
  >
  > This is an interface intended for use when the MIME type is already known.
  > Using an analyzer not matched to the file may cause unexpected results.

  ## Examples

      {:ok, analyzer} = PhilomenaMedia.Analyzers.analyzer("image/png")
      :error = PhilomenaMedia.Analyzers.analyzer("application/octet-stream")

  """
  @spec analyzer(Mime.t()) :: {:ok, module()} | :error
  def analyzer(content_type)

  def analyzer("image/gif"), do: {:ok, Gif}
  def analyzer("image/jpeg"), do: {:ok, Jpeg}
  def analyzer("image/png"), do: {:ok, Png}
  def analyzer("image/svg+xml"), do: {:ok, Svg}
  def analyzer("video/webm"), do: {:ok, Webm}
  def analyzer(_content_type), do: :error

  @doc """
  Attempts a MIME type check and analysis on the given `m:Plug.Upload`.

  ## Examples

      file = %Plug.Upload{...}
      {:ok, %Result{...}} = Analyzers.analyze_upload(file)

  """
  @spec analyze_upload(Plug.Upload.t()) ::
          {:ok, Result.t()} | {:unsupported_mime, Mime.t()} | :error
  def analyze_upload(%Plug.Upload{path: path}), do: analyze_path(path)
  def analyze_upload(_upload), do: :error

  @doc """
  Attempts a MIME type check and analysis on the given path.

  ## Examples

      file = "image_file.png"
      {:ok, %Result{...}} = Analyzers.analyze_path(file)

      file = "text_file.txt"
      :error = Analyzers.analyze_path(file)

  """
  def analyze_path(path) when is_binary(path) do
    with {:ok, mime} <- Mime.file(path),
         {:ok, analyzer} <- analyzer(mime) do
      {:ok, analyzer.analyze(path)}
    else
      error ->
        error
    end
  end

  def analyze_path(_path), do: :error
end
