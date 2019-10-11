defmodule Philomena.Search.String do
  def normalize(str) do
    str
    |> String.replace("\r", "")
    |> String.split("\n", trim: true)
    |> Enum.map(fn s -> "(#{s})" end)
    |> Enum.join(" || ")
  end
end
