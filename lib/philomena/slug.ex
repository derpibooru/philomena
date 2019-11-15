defmodule Philomena.Slug do
  def slug(string) when is_binary(string) do
    string
    |> String.replace("-", "-dash-")
    |> String.replace("/", "-fwslash-")
    |> String.replace("\\", "-bwslash-")
    |> String.replace(":", "-colon-")
    |> String.replace(".", "-dot-")
    |> String.replace("+", "-plus-")
    |> URI.encode()
    |> String.replace("%20", "+")
  end

  def slug(_string), do: ""
end