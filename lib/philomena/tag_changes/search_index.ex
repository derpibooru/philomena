defmodule Philomena.TagChanges.SearchIndex do
  @moduledoc false

  @behaviour PhilomenaQuery.Search.Index

  @impl true
  def version do
    1
  end

  @impl true
  def index_name do
    "tag_changes"
  end

  @impl true
  def mapping do
    %{
      settings: %{
        index: %{
          number_of_shards: 5,
          max_result_window: 10_000_000
        }
      },
      mappings: %{
        dynamic: false,
        properties: %{
          id: %{type: "integer"},
          image_id: %{type: "keyword"},
          created_at: %{type: "date"},
          tag: %{type: "keyword"},
          added_tag: %{type: "keyword"},
          removed_tag: %{type: "keyword"},
          tag_id: %{type: "keyword"},
          added_tag_id: %{type: "keyword"},
          removed_tag_id: %{type: "keyword"},
          tag_count: %{type: "integer"},
          added_tag_count: %{type: "integer"},
          removed_tag_count: %{type: "integer"},
          ip: %{type: "ip"},
          fingerprint: %{type: "keyword"},
          user: %{type: "keyword"},
          true_user: %{type: "keyword"},
          user_id: %{type: "keyword"},
          true_user_id: %{type: "keyword"},
          anonymous: %{type: "boolean"}
        }
      }
    }
  end

  @impl true
  def as_json(tag_change) do
    has_user = !!tag_change.user_id

    anonymous =
      !has_user or
        (!!tag_change.image.user_id and
           tag_change.image.user_id == tag_change.user_id and
           tag_change.image.anonymous)

    {added_tags, removed_tags} = Enum.split_with(tag_change.tag_change_tags, & &1.added)

    %{
      id: tag_change.id,
      image_id: tag_change.image_id,
      user:
        if(!anonymous,
          do: String.downcase(tag_change.user.name)
        ),
      user_id: if(!anonymous, do: tag_change.user_id),
      true_user: if(has_user, do: String.downcase(tag_change.user.name)),
      true_user_id: tag_change.user_id,
      anonymous: anonymous,
      ip: to_string(tag_change.ip),
      fingerprint: tag_change.fingerprint,
      created_at: tag_change.created_at,
      tag: tags_to_name_list(tag_change.tag_change_tags),
      added_tag: tags_to_name_list(added_tags),
      removed_tag: tags_to_name_list(removed_tags),
      tag_id: tags_to_id_list(tag_change.tag_change_tags),
      added_tag_id: tags_to_id_list(added_tags),
      removed_tag_id: tags_to_id_list(removed_tags),
      tag_count: length(tag_change.tag_change_tags),
      added_tag_count: length(added_tags),
      removed_tag_count: length(removed_tags)
    }
  end

  defp tags_to_id_list(tags), do: Enum.map(tags, & &1.tag_id)

  defp tags_to_name_list(tags) do
    tags
    |> Enum.flat_map(&([&1.tag] ++ &1.tag.aliases))
    |> Enum.map(& &1.name)
  end

  def user_name_update_by_query(old_name, new_name) do
    old_name = String.downcase(old_name)
    new_name = String.downcase(new_name)

    %{
      query: %{term: %{true_user: old_name}},
      replacements: [
        %{path: ["user"], old: old_name, new: new_name},
        %{path: ["true_user"], old: old_name, new: new_name}
      ],
      set_replacements: []
    }
  end
end
