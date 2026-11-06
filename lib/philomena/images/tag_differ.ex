defmodule Philomena.Images.TagDiffer do
  import Ecto.Changeset

  alias Philomena.Tags.Tag

  def diff_inputs(old_tag_input, tag_input) do
    old_tag_names =
      old_tag_input
      |> Tag.parse_tag_list()
      |> MapSet.new()

    new_tag_names =
      tag_input
      |> Tag.parse_tag_list()
      |> MapSet.new()

    added_tag_names = MapSet.difference(new_tag_names, old_tag_names)
    removed_tag_names = MapSet.difference(old_tag_names, new_tag_names)

    %{
      added: Enum.to_list(added_tag_names),
      removed: Enum.to_list(removed_tag_names)
    }
  end

  def apply(changeset, added_tag_list, removed_tag_list, excluded_tag_list) do
    excluded_tag_set = to_set(excluded_tag_list)
    added_tag_set = to_set(added_tag_list)
    removed_tag_set = to_set(removed_tag_list)

    # It should never be possible for tag editing to modify membership
    # of an excluded tag.
    added_tag_set = Map.drop(added_tag_set, Map.keys(excluded_tag_set))
    removed_tag_set = Map.drop(removed_tag_set, Map.keys(excluded_tag_set))

    tags = get_field(changeset, :tags)
    {tags, actually_added, actually_removed} = apply_changes(tags, added_tag_set, removed_tag_set)

    changeset
    |> put_change(:added_tags, actually_added)
    |> put_change(:removed_tags, actually_removed)
    |> put_assoc(:tags, tags)
  end

  defp apply_changes(tags, added_set, removed_set) do
    tag_set = to_set(tags)

    desired_tags =
      tag_set
      |> Map.drop(Map.keys(removed_set))
      |> Map.merge(added_set)

    actually_added =
      Map.drop(desired_tags, Map.keys(tag_set))

    actually_removed =
      Map.drop(tag_set, Map.keys(desired_tags))

    {
      to_tag_list(desired_tags),
      to_tag_list(actually_added),
      to_tag_list(actually_removed)
    }
  end

  defp to_set(tags) do
    Map.new(tags, &{&1.id, &1})
  end

  defp to_tag_list(set) do
    Enum.map(set, fn {_k, v} -> v end)
  end
end
