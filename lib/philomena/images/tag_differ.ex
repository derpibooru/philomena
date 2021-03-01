defmodule Philomena.Images.TagDiffer do
  import Ecto.Changeset
  import Ecto.Query

  alias Philomena.Tags.Tag
  alias Philomena.Repo

  def diff_input(changeset, old_tags, new_tags, excluded_tags) do
    excluded_ids = Enum.map(excluded_tags, & &1.id)

    old_set = to_set(old_tags)
    new_set = to_set(new_tags)

    tags = changeset |> get_field(:tags)
    added_tags = added_set(old_set, new_set, excluded_ids)
    removed_tags = removed_set(old_set, new_set, excluded_ids)

    {tags, actually_added, actually_removed} = apply_changes(tags, added_tags, removed_tags)

    changeset
    |> put_change(:added_tags, actually_added)
    |> put_change(:removed_tags, actually_removed)
    |> put_assoc(:tags, tags)
  end

  defp added_set(old_set, new_set, excluded_ids) do
    # new_tags - old_tags
    added_set =
      new_set
      |> Map.drop(Map.keys(old_set))

    implied_set =
      added_set
      |> Enum.flat_map(fn {_k, v} -> v.implied_tags end)
      |> List.flatten()
      |> to_set()

    added_and_implied_set = Map.merge(added_set, implied_set)

    oc_set =
      added_and_implied_set
      |> Enum.filter(fn {_k, v} -> v.namespace == "oc" end)
      |> get_oc_tag()

    added_and_implied_set
    |> Map.merge(oc_set)
    |> Map.drop(excluded_ids)
  end

  defp removed_set(old_set, new_set, excluded_ids) do
    # old_tags - new_tags
    old_set
    |> Map.drop(Map.keys(new_set))
    |> Map.drop(excluded_ids)
  end

  defp get_oc_tag([]), do: Map.new()

  defp get_oc_tag(_any_oc_tag) do
    Tag
    |> where(name: "oc")
    |> Repo.all()
    |> to_set()
  end

  defp to_set(tags) do
    tags |> Map.new(&{&1.id, &1})
  end

  defp to_tag_list(set) do
    set |> Enum.map(fn {_k, v} -> v end)
  end

  defp apply_changes(tags, added_set, removed_set) do
    tag_set = tags |> to_set()

    desired_tags =
      tag_set
      |> Map.drop(Map.keys(removed_set))
      |> Map.merge(added_set)

    actually_added =
      desired_tags
      |> Map.drop(Map.keys(tag_set))

    actually_removed =
      tag_set
      |> Map.drop(Map.keys(desired_tags))

    tags = desired_tags |> to_tag_list()
    actually_added = actually_added |> to_tag_list()
    actually_removed = actually_removed |> to_tag_list()

    {tags, actually_added, actually_removed}
  end
end
