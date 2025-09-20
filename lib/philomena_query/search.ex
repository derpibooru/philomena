defmodule PhilomenaQuery.Search do
  @moduledoc """
  Low-level search engine interaction.

  This module generates and delivers search bodies to the OpenSearch backend.

  Note that before an index can be used to index or query documents, a call to
  `create_index!/1` must be made. When setting up an application, or dealing with data loss
  in the search engine, you must call `create_index!/1` before running an indexing task.
  """

  alias PhilomenaQuery.Batch
  alias PhilomenaQuery.Search.Api
  alias Philomena.Repo
  require Logger
  import Ecto.Query

  # todo: fetch through compile_env?
  @policy Philomena.SearchPolicy

  @typedoc """
  Any schema module which has an associated search index. See the policy module
  for more information.
  """
  @type schema_module :: @policy.schema_module()

  @typedoc """
  Represents an object which may be operated on via `m:Ecto.Query`.

  This could be a schema object (e.g. `m:Philomena.Images.Image`) or a fully formed query
  `from i in Image, where: i.hidden_from_users == false`.
  """
  @type queryable :: any()

  @typedoc """
  A query body, as deliverable to any index's `_search` endpoint.

  See the query DSL documentation for additional information:
  https://opensearch.org/docs/latest/query-dsl/
  """
  @type query_body :: map()

  @typedoc """
  Given a term at the given path, replace the old term with the new term.

  `path` is a list of names to be followed to find the old term. For example,
  a document containing `{"condiments": "dijon"}` would permit `["condiments"]`
  as the path, and a document containing `{"namespaced_tags": {"name": ["old"]}}`
  would permit `["namespaced_tags", "name"]` as the path.
  """
  @type replacement :: %{
          path: [String.t()],
          old: term(),
          new: term()
        }

  @type search_definition :: %{
          module: schema_module(),
          body: query_body(),
          page_number: integer(),
          page_size: integer()
        }

  @type pagination_params :: %{
          optional(:page_number) => integer(),
          optional(:page_size) => integer()
        }

  @doc ~S"""
  Create the index with the module's index name and mapping.

  `PUT /#{index_name}`

  You **must** use this function before indexing documents in order for the mapping to be created
  correctly. If you index documents without a mapping created, the search engine will create a
  mapping which does not contain the correct types for mapping fields, which will require
  destroying and recreating the index.

  ## Example

      iex> Search.create_index!(Image)

  """
  @spec create_index!(schema_module()) :: any()
  def create_index!(module) do
    index = @policy.index_for(module)

    Api.create_index(@policy.opensearch_url(), index.index_name(), index.mapping())
  end

  @doc ~S"""
  Delete the index with the module's index name.

  `DELETE /#{index_name}`

  This undoes the effect of `create_index!/1` and removes the index permanently, deleting
  all indexed documents within.

  ## Example

      iex> Search.delete_index!(Image)

  """
  @spec delete_index!(schema_module()) :: any()
  def delete_index!(module) do
    index = @policy.index_for(module)

    Api.delete_index(@policy.opensearch_url(), index.index_name())
  end

  @doc ~S"""
  Update the schema mapping for the module's index name.

  `PUT /#{index_name}/_mapping`

  This is used to add new fields to an existing search mapping. This cannot be used to
  remove fields; removing fields requires recreating the index.

  ## Example

      iex> Search.update_mapping!(Image)

  """
  @spec update_mapping!(schema_module()) :: any()
  def update_mapping!(module) do
    index = @policy.index_for(module)

    index_name = index.index_name()
    mapping = index.mapping().mappings.properties

    Api.update_index_mapping(@policy.opensearch_url(), index_name, %{properties: mapping})
  end

  @doc ~S"""
  Add a single document to the index named by the module.

  `PUT /#{index_name}/_doc/#{id}`

  This allows the search engine to query the document.

  Note that indexing is near real-time and requires an index refresh before the document will
  become visible. Unless changed in the mapping, this happens after 5 seconds have elapsed.

  ## Example

      iex> Search.index_document(%Image{...}, Image)

  """
  @spec index_document(struct(), schema_module()) :: any()
  def index_document(doc, module) do
    index = @policy.index_for(module)
    data = index.as_json(doc)

    Api.index_document(@policy.opensearch_url(), index.index_name(), data, data.id)
  end

  @doc ~S"""
  Remove a single document from the index named by the module.

  `DELETE /#{index_name}/_doc/#{id}`

  This undoes the effect of `index_document/2`; it instructs the search engine to discard
  the document and no longer return it in queries.

  Note that indexing is near real-time and requires an index refresh before the document will
  be removed. Unless changed in the mapping, this happens after 5 seconds have elapsed.

  ## Example

      iex> Search.delete_document(image.id, Image)

  """
  @spec delete_document(term(), schema_module()) :: any()
  def delete_document(id, module) do
    index = @policy.index_for(module)

    Api.delete_document(@policy.opensearch_url(), index.index_name(), id)
  end

  @doc """
  Efficiently index a batch of documents in the index named by the module.

  This function is substantially more efficient than running `index_document/2` for
  each instance of a schema struct and can index with hundreds of times the throughput.

  The queryable should be a schema type with its indexing preloads included in
  the query. The options are forwarded to `PhilomenaQuery.Batch.record_batches/3`.

  Note that indexing is near real-time and requires an index refresh before documents will
  become visible. Unless changed in the mapping, this happens after 5 seconds have elapsed.

  > #### Warning {: .warning}
  > The returned stream must be enumerated for the reindex to process. If you do not care
  > about the progress IDs yielded, use `reindex/3` instead.

  ## Example

      query =
        from i in Image,
          where: i.id < 100_000,
          preload: ^Images.indexing_preloads()

      query
      |> Search.reindex_stream(Image, batch_size: 1024)
      |> Enum.each(&IO.inspect/1)

  """
  @spec reindex_stream(queryable(), schema_module(), Batch.batch_options()) ::
          Enumerable.t({:ok, integer()})
  def reindex_stream(queryable, module, opts \\ []) do
    max_concurrency = Keyword.get(opts, :max_concurrency, 1)
    index = @policy.index_for(module)

    queryable
    |> Batch.query_batches(opts)
    |> Task.async_stream(
      fn query ->
        records = Repo.all(query)

        lines =
          Enum.flat_map(records, fn record ->
            doc = index.as_json(record)

            [
              %{index: %{_index: index.index_name(), _id: doc.id}},
              doc
            ]
          end)

        Api.bulk(@policy.opensearch_url(), lines)

        last_id(records)
      end,
      timeout: :infinity,
      max_concurrency: max_concurrency
    )
    |> flatten_stream()
  end

  defp last_id([]), do: []
  defp last_id(records), do: [Enum.max_by(records, & &1.id).id]

  @spec flatten_stream(Enumerable.t({:ok, [integer()]})) :: Enumerable.t({:ok, integer()})
  defp flatten_stream(stream) do
    # Converts [{:ok, [1, 2]}] into [{:ok, 1}, {:ok, 2}]
    Stream.transform(stream, [], fn {:ok, last_id}, _ ->
      {Enum.map(last_id, &{:ok, &1}), []}
    end)
  end

  @doc """
  Efficiently index a batch of documents in the index named by the module.

  This function is substantially more efficient than running `index_document/2` for
  each instance of a schema struct and can index with hundreds of times the throughput.

  The queryable should be a schema type with its indexing preloads included in
  the query. The options are forwarded to `PhilomenaQuery.Batch.record_batches/3`.

  Note that indexing is near real-time and requires an index refresh before documents will
  become visible. Unless changed in the mapping, this happens after 5 seconds have elapsed.

  ## Example

      query =
        from i in Image,
          where: i.id < 100_000,
          preload: ^Images.indexing_preloads()

      Search.reindex(query, Image, batch_size: 1024)

  """
  @spec reindex(queryable(), schema_module(), Batch.batch_options()) :: :ok
  def reindex(queryable, module, opts \\ []) do
    queryable
    |> reindex_stream(module, opts)
    |> Stream.run()
  end

  @doc ~S"""
  Asynchronously update all documents in the given index matching a query.

  `POST /#{index_name}/_update_by_query`

  This is used to replace values in documents on the fly without requiring a more-expensive
  reindex operation from the database.

  `set_replacements` are used to rename values in fields which are conceptually sets (arrays).
  `replacements` are used to rename values in fields which are standalone terms.

  Both `replacements` and `set_replacements` may be specified. Specifying neither will waste
  the search engine's time evaluating the query and indexing the documents, so be sure to
  specify at least one.

  This function does not wait for completion of the update.

  ## Examples

      query_body = %{term: %{"namespaced_tags.name" => old_name}}
      replacement = %{path: ["namespaced_tags", "name"], old: old_name, new: new_name}
      Search.update_by_query(Image, query_body, [], [replacement])

      query_body = %{term: %{author: old_name}}
      set_replacement = %{path: ["author"], old: old_name, new: new_name}
      Search.update_by_query(Post, query_body, [set_replacement], [])

  """
  @spec update_by_query(schema_module(), query_body(), [replacement()], [replacement()]) :: any()
  def update_by_query(module, query_body, set_replacements, replacements) do
    index = @policy.index_for(module)

    # "Painless" scripting language
    script = """
      // Replace values in "sets" (arrays in the source document)
      for (int i = 0; i < params.set_replacements.length; ++i) {
        def replacement = params.set_replacements[i];
        def path        = replacement.path;
        def old_value   = replacement.old;
        def new_value   = replacement.new;
        def reference   = ctx._source;

        for (int j = 0; j < path.length; ++j) {
          reference = reference[path[j]];
        }

        for (int j = 0; j < reference.length; ++j) {
          if (reference[j].equals(old_value)) {
            reference[j] = new_value;
          }
        }
      }

      // Replace values in standalone fields
      for (int i = 0; i < params.replacements.length; ++i) {
        def replacement = params.replacements[i];
        def path        = replacement.path;
        def old_value   = replacement.old;
        def new_value   = replacement.new;
        def reference   = ctx._source;

        // A little bit more complicated: go up to the last one before it
        // so that the value can actually be replaced

        for (int j = 0; j < path.length - 1; ++j) {
          reference = reference[path[j]];
        }

        if (reference[path[path.length - 1]] != null && reference[path[path.length - 1]].equals(old_value)) {
          reference[path[path.length - 1]] = new_value;
        }
      }
    """

    body =
      %{
        script: %{
          source: script,
          params: %{
            set_replacements: set_replacements,
            replacements: replacements
          }
        },
        query: query_body
      }

    Api.update_by_query(@policy.opensearch_url(), index.index_name(), body)
  end

  @doc ~S"""
  Search the index named by the module.

  `GET /#{index_name}/_search`

  Given a query body, this returns the raw query results.

  ## Example

      iex> Search.search(Image, %{query: %{match_all: %{}}})
      %{
        "_shards" => %{"failed" => 0, "skipped" => 0, "successful" => 5, "total" => 5},
        "hits" => %{
          "hits" => [%{"_id" => "1", "_index" => "images", "_score" => 1.0, ...}, ...]
          "max_score" => 1.0,
          "total" => %{"relation" => "eq", "value" => 6}
        },
        "timed_out" => false,
        "took" => 1
      }

  """
  @spec search(schema_module(), query_body()) :: map()
  def search(module, query_body) do
    index = @policy.index_for(module)

    {:ok, %{body: results, status: 200}} =
      Api.search(@policy.opensearch_url(), index.index_name(), query_body)

    results
  end

  @doc ~S"""
  Given maps of module and body, searches each index with the respective body.

  `GET /_all/_search`

  This is more efficient than performing a `search/1` for each index individually.
  Like `search/1`, this returns the raw query results.

  ## Example

      iex> Search.msearch([
      ...>   %{module: Image, body: %{query: %{match_all: %{}}}},
      ...>   %{module: Post, body: %{query: %{match_all: %{}}}}
      ...> ])
      [
        %{"_shards" => ..., "hits" => ..., "timed_out" => false, "took" => 1},
        %{"_shards" => ..., "hits" => ..., "timed_out" => false, "took" => 2}
      ]

  """
  @spec msearch([search_definition()]) :: [map()]
  def msearch(definitions) do
    msearch_body =
      Enum.flat_map(definitions, fn def ->
        [
          %{index: @policy.index_for(def.module).index_name()},
          def.body
        ]
      end)

    {:ok, %{body: results, status: 200}} =
      Api.msearch(@policy.opensearch_url(), msearch_body)

    results["responses"]
  end

  @doc """
  Transforms an index module, query body, and pagination parameters into a query suitable
  for submission to the search engine.

  Any of the following functions may be used for submission:
  - `search_results/1`
  - `msearch_results/1`
  - `search_records/2`
  - `msearch_records/2`
  - `search_records_with_hits/2`
  - `msearch_records_with_hits/2`

  ## Example

      iex> Search.search_definition(Image, %{query: %{match_all: %{}}}, %{page_number: 3, page_size: 50})
      %{
        module: Image,
        body: %{
          size: 50,
          query: %{match_all: %{}},
          from: 100,
          _source: false,
          track_total_hits: true
        },
        page_size: 50,
        page_number: 3
      }

  """
  @spec search_definition(schema_module(), query_body(), pagination_params()) ::
          search_definition()
  def search_definition(module, search_query, pagination_params \\ %{}) do
    page_number = pagination_params[:page_number] || 1
    page_size = pagination_params[:page_size] || 25

    search_query =
      Map.merge(search_query, %{
        from: (page_number - 1) * page_size,
        size: page_size,
        _source: false,
        track_total_hits: true
      })

    %{
      module: module,
      body: search_query,
      page_number: page_number,
      page_size: page_size
    }
  end

  defp process_results(results, definition) do
    time = results["took"]
    count = results["hits"]["total"]["value"]
    entries = Enum.map(results["hits"]["hits"], &{String.to_integer(&1["_id"]), &1})

    Logger.debug("[Search] Query took #{time}ms")
    Logger.debug("[Search] #{JSON.encode!(definition.body)}")

    %Scrivener.Page{
      entries: entries,
      page_number: definition.page_number,
      page_size: definition.page_size,
      total_entries: count,
      total_pages: div(count + definition.page_size - 1, definition.page_size)
    }
  end

  @doc """
  Given a search definition generated by `search_definition/3`, submit the query and return
  a `m:Scrivener.Page` of results.

  The `entries` in the page are a list of tuples of record IDs paired with the hit that generated
  them.

  ## Example

      iex> Search.search_results(definition)
      %Scrivener.Page{
        entries: [{1, %{"_id" => "1", ...}}, ...],
        page_number: 1,
        page_size: 25,
        total_entries: 6,
        total_pages: 1
      }

  """
  @spec search_results(search_definition()) :: Scrivener.Page.t()
  def search_results(definition) do
    process_results(search(definition.module, definition.body), definition)
  end

  @doc """
  Given a list of search definitions, each generated by `search_definition/3`, submit the query
  and return a corresponding list of `m:Scrivener.Page` for each query.

  The `entries` in the page are a list of tuples of record IDs paired with the hit that generated
  them.

  ## Example

      iex> Search.msearch_results([definition])
      [
        %Scrivener.Page{
          entries: [{1, %{"_id" => "1", ...}}, ...],
          page_number: 1,
          page_size: 25,
          total_entries: 6,
          total_pages: 1
        }
      ]

  """
  @spec msearch_results([search_definition()]) :: [Scrivener.Page.t()]
  def msearch_results(definitions) do
    Enum.map(Enum.zip(msearch(definitions), definitions), fn {result, definition} ->
      process_results(result, definition)
    end)
  end

  defp load_records_from_results(results, ecto_queries) do
    Enum.map(Enum.zip(results, ecto_queries), fn {page, ecto_query} ->
      {ids, hits} = Enum.unzip(page.entries)

      records =
        ecto_query
        |> where([m], m.id in ^ids)
        |> Repo.all()
        |> Enum.sort_by(&Enum.find_index(ids, fn el -> el == &1.id end))

      %{page | entries: Enum.zip(records, hits)}
    end)
  end

  @doc """
  Given a search definition generated by `search_definition/3`, submit the query and return a
  `m:Scrivener.Page` of results.

  The `entries` in the page are a list of tuples of schema structs paired with the hit that
  generated them.

  ## Example

      iex> Search.search_records_with_hits(definition, preload(Image, :tags))
      %Scrivener.Page{
        entries: [{%Image{id: 1, ...}, %{"_id" => "1", ...}}, ...],
        page_number: 1,
        page_size: 25,
        total_entries: 6,
        total_pages: 1
      }

  """
  @spec search_records_with_hits(search_definition(), queryable()) :: Scrivener.Page.t()
  def search_records_with_hits(definition, ecto_query) do
    [page] = load_records_from_results([search_results(definition)], [ecto_query])

    page
  end

  @doc """
  Given a list of search definitions, each generated by `search_definition/3`, submit the query
  and return a corresponding list of `m:Scrivener.Page` for each query.

  The `entries` in the page are a list of tuples of schema structs paired with the hit that
  generated them.

  ## Example

      iex> Search.msearch_records_with_hits([definition], [preload(Image, :tags)])
      [
        %Scrivener.Page{
          entries: [{%Image{id: 1, ...}, %{"_id" => "1", ...}}, ...],
          page_number: 1,
          page_size: 25,
          total_entries: 6,
          total_pages: 1
        }
      ]

  """
  @spec msearch_records_with_hits([search_definition()], [queryable()]) :: [Scrivener.Page.t()]
  def msearch_records_with_hits(definitions, ecto_queries) do
    load_records_from_results(msearch_results(definitions), ecto_queries)
  end

  @doc """
  Given a search definition generated by `search_definition/3`, submit the query and return a
  `m:Scrivener.Page` of results.

  The `entries` in the page are a list of schema structs.

  ## Example

      iex> Search.search_records(definition, preload(Image, :tags))
      %Scrivener.Page{
        entries: [%Image{id: 1, ...}, ...],
        page_number: 1,
        page_size: 25,
        total_entries: 6,
        total_pages: 1
      }

  """
  @spec search_records(search_definition(), queryable()) :: Scrivener.Page.t()
  def search_records(definition, ecto_query) do
    page = search_records_with_hits(definition, ecto_query)
    {records, _hits} = Enum.unzip(page.entries)

    %{page | entries: records}
  end

  @doc """
  Given a list of search definitions, each generated by `search_definition/3`, submit the query
  and return a corresponding list of `m:Scrivener.Page` for each query.

  The `entries` in the page are a list of schema structs.

  ## Example

      iex> Search.msearch_records([definition], [preload(Image, :tags)])
      [
        %Scrivener.Page{
          entries: [%Image{id: 1, ...}, ...],
          page_number: 1,
          page_size: 25,
          total_entries: 6,
          total_pages: 1
        }
      ]

  """
  @spec msearch_records([search_definition()], [queryable()]) :: [Scrivener.Page.t()]
  def msearch_records(definitions, ecto_queries) do
    Enum.map(load_records_from_results(msearch_results(definitions), ecto_queries), fn page ->
      {records, _hits} = Enum.unzip(page.entries)

      %{page | entries: records}
    end)
  end
end
