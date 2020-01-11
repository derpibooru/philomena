defmodule Philomena.Filename do
  @moduledoc """
  Utilities for building arbitrary filenames for uploaded files.
  """

  @spec build(String.t()) :: String.t()
  def build(extension) do
    [
      time_identifier(DateTime.utc_now()),
      "/",
      usec_identifier(),
      pid_identifier(),
      ".",
      extension
    ]
    |> Enum.join()
  end

  defp time_identifier(time) do
    Enum.join([time.year, time.month, time.day], "/")
  end

  defp usec_identifier do
    DateTime.utc_now()
    |> DateTime.to_unix(:microsecond)
    |> to_string()
  end

  defp pid_identifier do
    self()
    |> :erlang.pid_to_list()
    |> to_string()
    |> String.replace(~r/[^0-9]/, "")
  end
end
