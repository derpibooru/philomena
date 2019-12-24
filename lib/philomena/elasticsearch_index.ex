defmodule Philomena.ElasticsearchIndex do
  # Returns the index name for the index.
  # This is usually a collection name like "images".
  @callback index_name() :: String.t()

  # Returns the document type for the index.
  # This is usually the singular of the index name, like "image".
  # 
  # TODO: Remove for ES 7.0
  @callback doc_type() :: String.t()

  # Returns the mapping and settings for the index.
  @callback mapping() :: map()

  # Returns the JSON representation of the given struct
  # for indexing in Elasticsearch.
  @callback as_json(struct()) :: map()
end
