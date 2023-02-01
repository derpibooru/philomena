defmodule Philomena.Filename do
  @moduledoc """
  Utilities for building arbitrary filenames for uploaded files.
  """

  @spec build(String.t()) :: String.t()
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
