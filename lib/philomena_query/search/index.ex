defmodule PhilomenaQuery.Search.Index do
  @moduledoc """
  Behaviour module for schemas with search indexing.
  """

  @doc """
  Returns the index name for the index.

  This is usually a collection name like "images".

  See https://opensearch.org/docs/latest/api-reference/index-apis/create-index/ for
  reference on index naming restrictions.
  """
  @callback index_name() :: String.t()

  @doc """
  Returns the mapping and settings for the index.

  See https://opensearch.org/docs/latest/api-reference/index-apis/put-mapping/ for
  reference on the mapping syntax, and the following pages for which types may be
  used in mappings:
  - https://opensearch.org/docs/latest/field-types/
  - https://opensearch.org/docs/latest/analyzers/index-analyzers/
  """
  @callback mapping() :: map()

  @doc """
  Returns the JSON representation of the given struct for indexing in OpenSearch.

  See https://opensearch.org/docs/latest/api-reference/document-apis/index-document/ for
  reference on how this value is used.
  """
  @callback as_json(struct()) :: map()
end
