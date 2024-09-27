defmodule Philomena.Tags.SearchIndex do
  @behaviour PhilomenaQuery.Search.Index

  @impl true
  def index_name do
    "tags"
  end

  @impl true
  def mapping do
    %{
      settings: %{
        index: %{
          number_of_shards: 5,
          max_result_window: 10_000_000,
          analysis: %{
            analyzer: %{
              tag_snowball: %{
                tokenizer: :letter,
                filter: [:asciifolding, :snowball]
              }
            }
          }
        }
      },
      mappings: %{
        dynamic: false,
        properties: %{
          id: %{type: "integer"},
          images: %{type: "integer"},
          slug: %{type: "keyword"},
          name: %{type: "keyword"},
          name_in_namespace: %{type: "keyword"},
          namespace: %{type: "keyword"},
          aliased_tag: %{type: "keyword"},
          aliases: %{type: "keyword"},
          implied_tags: %{type: "keyword"},
          implied_tag_ids: %{type: "keyword"},
          implied_by_tags: %{type: "keyword"},
          category: %{type: "keyword"},
          aliased: %{type: "boolean"},
          analyzed_name: %{
            type: "text",
            fields: %{
              nlp: %{type: "text", analyzer: "tag_snowball"},
              ngram: %{type: "keyword"}
            }
          },
          description: %{type: "text", analyzer: "snowball"},
          short_description: %{type: "text", analyzer: "snowball"}
        }
      }
    }
  end

  @impl true
  def as_json(tag) do
    %{
      id: tag.id,
      images: tag.images_count,
      slug: tag.slug,
      name: tag.name,
      name_in_namespace: tag.name_in_namespace,
      namespace: tag.namespace,
      analyzed_name: tag.name,
      implied_tags: tag.implied_tags |> Enum.map(& &1.name),
      implied_tag_ids: tag.implied_tags |> Enum.map(& &1.id),
      implied_by_tags: tag.implied_by_tags |> Enum.map(& &1.name),
      aliased_tag: if(!!tag.aliased_tag, do: tag.aliased_tag.name),
      aliases: tag.aliases |> Enum.map(& &1.name),
      category: tag.category,
      aliased: !!tag.aliased_tag,
      description: tag.description,
      short_description: tag.short_description
    }
  end
end
