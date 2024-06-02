defmodule PhilomenaMedia.Mime do
  @moduledoc """
  Utilities for determining the MIME type of a file via parsing.

  Many MIME type libraries assume the MIME type of the file by reading file extensions.
  This is inherently unreliable, as many websites disguise the content types of files with
  specific names for cost or bandwidth saving reasons. As processing depends on correctly
  identifying the type of a file, parsing the file contents is necessary.
  """

  @type t :: String.t()

  @doc """
  Gets the MIME type of the given pathname.

  ## Examples

      iex> PhilomenaMedia.Mime.file("image.png")
      {:ok, "image/png"}

      iex> PhilomenaMedia.Mime.file("file.txt")
      {:unsupported_mime, "text/plain"}

      iex> PhilomenaMedia.Mime.file("nonexistent.file")
      :error

  """
  @spec file(Path.t()) :: {:ok, t()} | {:unsupported_mime, t()} | :error
  def file(path) do
    System.cmd("file", ["-b", "--mime-type", path])
    |> case do
      {output, 0} ->
        true_mime(String.trim(output))

      _error ->
        :error
    end
  end

  @doc """
  Provides the "true" MIME type of this file.

  Some files are identified as a type they should not be based on how they are used by
  this library. These MIME types (and their "corrected") versions are:

  - `image/svg` -> `image/svg+xml`
  - `audio/webm` -> `video/webm`

  ## Examples

    iex> PhilomenaMedia.Mime.file("image.svg")
    "image/svg+xml"

    iex> PhilomenaMedia.Mime.file("audio.webm")
    "video/webm"

  """
  @spec true_mime(String.t()) :: {:ok, t()} | {:unsupported_mime, t()}
  def true_mime("image/svg"), do: {:ok, "image/svg+xml"}
  def true_mime("audio/webm"), do: {:ok, "video/webm"}

  def true_mime(mime)
      when mime in ~W(image/gif image/jpeg image/png image/svg+xml video/webm),
      do: {:ok, mime}

  def true_mime(mime), do: {:unsupported_mime, mime}
end
