defmodule Philomena.Analyzers do
  @moduledoc """
  Utilities for analyzing the format and various attributes of uploaded files.
  """

  alias Philomena.Mime

  alias Philomena.Analyzers.Gif
  alias Philomena.Analyzers.Jpeg
  alias Philomena.Analyzers.Png
  alias Philomena.Analyzers.Svg
  alias Philomena.Analyzers.Webm

  @doc """
  Returns an {:ok, analyzer} tuple, with the analyzer being a module capable
  of analyzing this content type, or :error.

  To use an analyzer, call the analyze/1 method on it with the path to the
  file. It will return a map such as the following:

      %{
        animated?: false,
        dimensions: {800, 600},
        duration: 0.0,
        extension: "png",
        mime_type: "image/png"
      }
  """
  @spec analyzer(binary()) :: {:ok, module()} | :error
  def analyzer(content_type)

  def analyzer("image/gif"), do: {:ok, Gif}
  def analyzer("image/jpeg"), do: {:ok, Jpeg}
  def analyzer("image/png"), do: {:ok, Png}
  def analyzer("image/svg+xml"), do: {:ok, Svg}
  def analyzer("video/webm"), do: {:ok, Webm}
  def analyzer(_content_type), do: :error

  @doc """
  Attempts a mime check and analysis on the given pathname or Plug.Upload.
  """
  @spec analyze(Plug.Upload.t() | String.t()) :: {:ok, map()} | :error
  def analyze(%Plug.Upload{path: path}), do: analyze(path)
  def analyze(path) when is_binary(path) do
    with {:ok, mime} <- Mime.file(path),
         {:ok, analyzer} <- analyzer(mime)
    do
      {:ok, analyzer.analyze(path)}
    else
      error ->
        error
    end
  end
  def analyze(_path), do: :error
end