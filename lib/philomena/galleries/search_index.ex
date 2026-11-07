defmodule Philomena.Galleries.SearchIndex do
  @behaviour PhilomenaQuery.Search.Index

  @impl true
  def version do
    2
  end

  @impl true
  def index_name do
    "galleries"
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
          image_count: %{type: "integer"},
          subscriber_count: %{type: "integer"},
          updated_at: %{type: "date"},
          created_at: %{type: "date"},
          title: %{type: "keyword"},
          true_creator_id: %{type: "keyword"},
          true_creator: %{type: "keyword"},
          creator_id: %{type: "keyword"},
          creator: %{type: "keyword"},
          image_ids: %{type: "keyword"},
          thumbnail_id: %{type: "keyword"},
          description: %{type: "text", analyzer: "snowball"},
          spoiler_warning: %{type: "text", analyzer: "snowball"},
          anonymous: %{type: "boolean"}
        }
      }
    }
  end

  @impl true
  def as_json(gallery) do
    %{
      id: gallery.id,
      image_count: gallery.image_count,
      subscriber_count: length(gallery.subscribers),
      updated_at: gallery.updated_at,
      created_at: gallery.created_at,
      title: String.downcase(gallery.title),
      true_creator_id: gallery.user_id,
      true_creator: if(!!gallery.user, do: String.downcase(gallery.user.name)),
      creator_id: if(!gallery.anonymous, do: gallery.user_id),
      creator: if(!!gallery.user and !gallery.anonymous, do: String.downcase(gallery.user.name)),
      image_ids: Enum.map(gallery.interactions, & &1.image_id),
      thumbnail_id: gallery.thumbnail_id,
      description: gallery.description,
      spoiler_warning: gallery.spoiler_warning,
      anonymous: gallery.anonymous
    }
  end

  def user_name_update_by_query(old_name, new_name) do
    old_name = String.downcase(old_name)
    new_name = String.downcase(new_name)

    %{
      query: %{term: %{true_creator: old_name}},
      replacements: [
        %{path: ["true_creator"], old: old_name, new: new_name},
        %{path: ["creator"], old: old_name, new: new_name}
      ],
      set_replacements: []
    }
  end
end
