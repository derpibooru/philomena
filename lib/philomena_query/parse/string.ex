defmodule PhilomenaQuery.Parse.String do
  @moduledoc """
  Search string normalization utilities.
  """

  @doc """
  Convert a multiline or empty search string into a single search string.

  ## Examples

      iex> Search.String.normalize(nil)
      ""

      iex> Search.String.normalize("foo\nbar")
      "(foo) || (bar)"

  """
  @spec normalize(String.t() | nil) :: String.t()
  def normalize(str)

  def normalize(nil) do
    ""
  end

  def normalize(str) do
    str
    |> String.replace("\r", "")
    |> String.split("\n", trim: true)
    |> Enum.map(fn s -> "(#{s})" end)
    |> Enum.join(" || ")
  end
end
