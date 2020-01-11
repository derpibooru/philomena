defmodule Philomena.Mime do
  @type mime :: String.t()

  @doc """
  Gets the mime type of the given pathname.
  """
  @spec file(String.t()) :: {:ok, mime()} | :error
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
  Provides the "true" content type of this file.

  Some files are identified incorrectly as a mime type they should not be.
  These incorrect mime types (and their "corrected") versions are:

    - image/svg -> image/svg+xml
    - audio/webm -> video/webm
  """
  @spec true_mime(String.t()) :: {:ok, mime()}
  def true_mime("image/svg"), do: {:ok, "image/svg+xml"}
  def true_mime("audio/webm"), do: {:ok, "video/webm"}

  def true_mime(mime)
      when mime in ~W(image/gif image/jpeg image/png image/svg+xml video/webm),
      do: {:ok, mime}

  def true_mime(_mime), do: :error
end
