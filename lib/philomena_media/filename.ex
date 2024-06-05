defmodule PhilomenaMedia.Filename do
  @moduledoc """
  Utilities for building arbitrary filenames for uploaded files.
  """

  @type extension :: String.t()

  @doc """
  This function builds a replacement "filename key" based on the supplied file extension.

  Names are generated in the form `year/month/day/uuid.ext`. It is recommended to avoid
  providing user-controlled file-extensions to this function; select them from a list of
  known extensions instead.

  ## Example

      iex> PhilomenaMedia.Filename.build("png")
      "2024/1/1/0bce8eea-17e0-11ef-b7d4-0242ac120006.png"

  """
  @spec build(extension()) :: String.t()
  def build(extension) do
    [
      time_identifier(DateTime.utc_now()),
      "/",
      UUID.uuid1(),
      ".",
      extension
    ]
    |> Enum.join()
  end

  defp time_identifier(time) do
    Enum.join([time.year, time.month, time.day], "/")
  end
end
