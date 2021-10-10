defmodule Philomena.Images.SourceDiffer do
  import Ecto.Changeset
  alias Philomena.Images.Source

  def diff_input(changeset, old_sources, new_sources) do
    old_set = MapSet.new(flatten_input(old_sources))
    new_set = MapSet.new(flatten_input(new_sources))

    source_set = MapSet.new(get_field(changeset, :sources), & &1.source)
    added_sources = MapSet.difference(new_set, old_set)
    removed_sources = MapSet.difference(old_set, new_set)

    {sources, actually_added, actually_removed} =
      apply_changes(source_set, added_sources, removed_sources)

    image_id = fetch_field!(changeset, :id)

    changeset
    |> put_change(:added_sources, actually_added)
    |> put_change(:removed_sources, actually_removed)
    |> put_assoc(:sources, source_structs(image_id, sources))
  end

  defp apply_changes(source_set, added_set, removed_set) do
    desired_sources =
      source_set
      |> MapSet.difference(removed_set)
      |> MapSet.union(added_set)

    actually_added =
      desired_sources
      |> MapSet.difference(source_set)
      |> Enum.to_list()

    actually_removed =
      source_set
      |> MapSet.difference(desired_sources)
      |> Enum.to_list()

    sources = Enum.to_list(desired_sources)
    actually_added = Enum.to_list(actually_added)
    actually_removed = Enum.to_list(actually_removed)

    {sources, actually_added, actually_removed}
  end

  defp source_structs(image_id, sources) do
    Enum.map(sources, &%Source{image_id: image_id, source: &1})
  end

  defp flatten_input(input) when is_map(input) do
    Enum.flat_map(Map.values(input), fn
      %{"source" => source} ->
        source = String.trim(source)

        if source != "" do
          [source]
        else
          []
        end

      _ -> []
    end)
  end

  defp flatten_input(_input) do
    []
  end
end
