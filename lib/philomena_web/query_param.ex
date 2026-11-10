defmodule PhilomenaWeb.QueryParam do
  @moduledoc """
  Helper function for normalizing parameters passed to context query builders.
  """

  @doc """
  Normalize a parameter key to a map, coercing it to an empty map
  if it does not exist or is the wrong type.
  """
  @spec query_param(map(), String.t()) :: map()
  def query_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_map(value) ->
        value

      _ ->
        %{}
    end
  end
end
