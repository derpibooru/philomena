defmodule PhilomenaQuery.Search.MappingDiff do
  @moduledoc """
  Classification of the difference between a live index definition and the
  desired one declared by a `PhilomenaQuery.Search.Index` module.

  Live values come from the search engine (`GET /{index}`) and are shaped
  differently from the Elixir-side declaration: keys are strings, settings
  values are stringified (`"number_of_shards" => "5"`), the settings contain
  server-generated keys (`uuid`, `creation_date`, ...), and the mappings carry
  the `_meta` block written at creation time. Comparison accounts for all of
  this; the desired definition is normalized by a JSON round-trip first.
  """

  @doc """
  Classify the difference between the live index definition and the desired one.

  `live` is `%{mapping: map(), settings: map()}` as returned by the engine for
  a single index; `desired` is a `mapping/0` result (`%{settings: ...,
  mappings: ...}`).

  Returns:

  - `:equal` - live matches desired
  - `:additive` - desired only adds new mapping properties, so it can be
    applied in place with `PUT /_mapping`
  - `:rebuild` - anything else: a settings difference, or a changed or removed
    mapping property

  Comparison is conservative by construction: any doubt classifies as
  `:rebuild`, which at worst causes an unnecessary rebuild.
  """
  @spec classify(%{mapping: map(), settings: map()}, map()) :: :equal | :additive | :rebuild
  def classify(%{mapping: live_mapping, settings: live_settings}, desired) do
    desired = normalize(desired)

    if subset?(desired["settings"], live_settings) do
      classify_mappings(Map.delete(live_mapping, "_meta"), desired["mappings"])
    else
      :rebuild
    end
  end

  # String-keys the desired definition so it is comparable with engine output.
  defp normalize(desired) do
    desired
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp classify_mappings(live, desired) when is_map(live) and is_map(desired) do
    {live_properties, live_rest} = Map.pop(live, "properties", %{})
    {desired_properties, desired_rest} = Map.pop(desired, "properties", %{})

    changed_or_removed? =
      Enum.any?(live_properties, fn {name, live_definition} ->
        case Map.fetch(desired_properties, name) do
          {:ok, desired_definition} -> not equal_values?(live_definition, desired_definition)
          :error -> true
        end
      end)

    cond do
      not equal_values?(live_rest, desired_rest) -> :rebuild
      changed_or_removed? -> :rebuild
      map_size(desired_properties) > map_size(live_properties) -> :additive
      true -> :equal
    end
  end

  defp classify_mappings(_live, _desired), do: :rebuild

  # Every key present in `desired` must exist in `live` with an equal value;
  # `live` may contain extra keys (server-generated settings).
  defp subset?(desired, live) when is_map(desired) and is_map(live) do
    Enum.all?(desired, fn {key, desired_value} ->
      case Map.fetch(live, key) do
        {:ok, live_value} when is_map(desired_value) -> subset?(desired_value, live_value)
        {:ok, live_value} -> equal_values?(desired_value, live_value)
        :error -> false
      end
    end)
  end

  defp subset?(_desired, _live), do: false

  # Deep equality with scalars compared stringified, since the engine returns
  # settings values and mapping flags like `dynamic` as strings.
  defp equal_values?(a, b) when is_map(a) and is_map(b) do
    Enum.sort(Map.keys(a)) == Enum.sort(Map.keys(b)) and
      Enum.all?(a, fn {key, value} -> equal_values?(value, Map.fetch!(b, key)) end)
  end

  defp equal_values?(a, b) when is_list(a) and is_list(b) do
    length(a) == length(b) and
      Enum.all?(Enum.zip(a, b), fn {x, y} -> equal_values?(x, y) end)
  end

  defp equal_values?(a, b) when is_map(a) or is_map(b) or is_list(a) or is_list(b), do: false

  defp equal_values?(a, b), do: stringify(a) == stringify(b)

  defp stringify(value) when is_binary(value), do: value
  defp stringify(value), do: to_string(value)
end
