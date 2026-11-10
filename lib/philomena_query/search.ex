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
  alias PhilomenaQuery.Search.WriteTargets
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
  Options accepted by `reindex/3` and `reindex_stream/3`.

  In addition to the batching options forwarded to `m:PhilomenaQuery.Batch`, the
  reindex path accepts `max_concurrency` (the number of concurrent batch tasks)
  and `targets` (an explicit list of physical indexes to write to).
  """
  @type reindex_options :: [
          {:batch_size, integer()}
          | {:id_field, atom()}
          | {:max_concurrency, pos_integer()}
          | {:targets, [String.t()]}
        ]

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

  @type named_search_definitions :: [{atom(), search_definition()}]
  @type named_record_searches :: [{atom(), {search_definition(), queryable()}}]

  @type pagination_params :: %{
          optional(:page_number) => integer(),
          optional(:page_size) => integer()
        }

  @doc """
  Return the name of the index which stores documents for the given schema
  module, including any environment prefix.

  Index modules define bare names (e.g. `"images"`); a prefix may be set
  with the `:opensearch_index_prefix` configuration key to namespace all
  indexes for the current environment. The test environment uses `"test_"`
  so test runs cannot touch development data on a shared cluster.

  ## Example

      iex> Search.index_name(Image)
      "images"

  """
  @spec index_name(schema_module()) :: String.t()
  def index_name(module) do
    prefixed_index_name(@policy.index_for(module))
  end

  defp prefixed_index_name(index) do
    prefix = Application.get_env(:philomena, :opensearch_index_prefix, "")

    "#{prefix}#{index.index_name()}"
  end

  # Index names document writes must be sent to. Normally this is just the
  # alias name; during an index migration it is every physical index backing
  # the alias, so the new index is complete when the alias is swapped onto it.
  # An explicit `targets:` option bypasses resolution (used by the migrator to
  # bulk into the new index only).
  @spec write_targets(module(), Keyword.t()) :: [String.t()]
  defp write_targets(index, opts) do
    Keyword.get(opts, :targets) || WriteTargets.targets_for(prefixed_index_name(index))
  end

  @spec physical_index_name(module(), pos_integer()) :: String.t()
  defp physical_index_name(index, version) do
    "#{prefixed_index_name(index)}_v#{version}"
  end

  @doc ~S"""
  Create a versioned physical index with the module's mapping, aliased to the
  module's index name.

  `PUT /#{index_name}_v#{version}`

  The physical index is named `#{index_name}_v#{version}`; the alias carrying
  the plain index name is attached in the same call, so the index becomes
  addressable under its usual name atomically. The mapping version is recorded
  in `mappings._meta` alongside any extra `meta:` entries.

  You **must** use this function before indexing documents in order for the mapping to be created
  correctly. If you index documents without a mapping created, the search engine will create a
  mapping which does not contain the correct types for mapping fields, which will require
  destroying and recreating the index.

  ## Options

  - `alias:` - set `false` to create the physical index without attaching the
    alias (a migration target which is swapped in later). Defaults to `true`.
  - `version:`, `mapping:` - override the index module's `version/0` and
    `mapping/0`. Used by `Philomena.SearchMigrator` tests to simulate version
    bumps. An overridden mapping must be atom-keyed like `mapping/0` results.
  - `meta:` - extra entries for the `mappings._meta` block, e.g. the
    migration start timestamp.

  Raises unless the search engine acknowledges the creation.

  ## Example

      iex> Search.create_index!(Image)
      :ok

  """
  @spec create_index!(schema_module(), Keyword.t()) :: :ok
  def create_index!(module, opts \\ []) do
    index = @policy.index_for(module)
    version = Keyword.get(opts, :version, index.version())
    mapping = Keyword.get(opts, :mapping, index.mapping())
    meta = opts |> Keyword.get(:meta, %{}) |> Map.put(:version, version)

    body =
      mapping
      |> put_in([:mappings, :_meta], meta)
      |> maybe_put_alias(prefixed_index_name(index), Keyword.get(opts, :alias, true))

    {:ok, %{status: 200}} =
      Api.create_index(@policy.opensearch_url(), physical_index_name(index, version), body)

    :ok
  end

  defp maybe_put_alias(body, alias_name, true), do: Map.put(body, :aliases, %{alias_name => %{}})
  defp maybe_put_alias(body, _alias_name, false), do: body

  @doc ~S"""
  Delete every physical index backing the module's index name.

  `DELETE /#{physical_index_name}` for each member

  This undoes the effect of `create_index!/2` and removes the indices
  permanently, deleting all indexed documents within. All members are removed:
  the aliased physical index, any unaliased migration target or orphan, and
  any bare concrete index occupying the alias name. Deleting an aliased index
  drops its alias with it.

  Succeeds when there is nothing to delete.

  ## Example

      iex> Search.delete_index!(Image)
      :ok

  """
  @spec delete_index!(schema_module()) :: :ok
  def delete_index!(module) do
    index = @policy.index_for(module)

    %{members: members} = alias_group(prefixed_index_name(index))

    Enum.each(members, fn member ->
      {:ok, %{status: status}} = Api.delete_index(@policy.opensearch_url(), member)

      unless status in [200, 404] do
        raise "Could not delete search index #{member} (status #{status})"
      end
    end)
  end

  @doc ~S"""
  Return the live cluster state for the module's index name, as consumed by
  `Philomena.SearchMigrator`.

  The returned map contains:

  - `alias` - the (prefixed) alias name
  - `status` - `:aliased` when a physical index holds the alias, `:legacy`
    when a bare concrete index occupies the alias name, `:missing` otherwise
  - `live_physical` - the index currently serving reads, if any
  - `live_version` - from the live index's `mappings._meta.version`, falling
    back to the `_v` name suffix; `nil` for legacy indices without either
  - `live_mapping`, `live_settings` - the live index's definition, for
    `m:PhilomenaQuery.Search.MappingDiff`
  - `orphans` - members which are not the live index (stale migration
  """
  @spec live_state(schema_module()) :: %{
          alias: String.t(),
          status: :missing | :legacy | :aliased,
          live_physical: String.t() | nil,
          live_version: pos_integer() | nil,
          live_mapping: map() | nil,
          live_settings: map() | nil,
          orphans: [String.t()]
        }
  def live_state(module) do
    index = @policy.index_for(module)
    alias_name = prefixed_index_name(index)

    %{members: members, aliased: aliased} = alias_group(alias_name)

    {status, live_physical} =
      cond do
        # More than one aliased member never happens through the migrator
        # (swaps are atomic); prefer the newest if it does.
        aliased != [] -> {:aliased, Enum.max_by(aliased, &(version_from_name(&1) || 0))}
        alias_name in members -> {:legacy, alias_name}
        true -> {:missing, nil}
      end

    state = %{
      alias: alias_name,
      status: status,
      live_physical: live_physical,
      live_version: nil,
      live_mapping: nil,
      live_settings: nil,
      orphans: members -- List.wrap(live_physical)
    }

    case live_physical do
      nil ->
        state

      name ->
        {:ok, %{status: 200, body: body}} = Api.get_index(@policy.opensearch_url(), name)
        %{"mappings" => mapping, "settings" => settings} = Map.fetch!(body, name)

        %{
          state
          | live_version: get_in(mapping, ["_meta", "version"]) || version_from_name(name),
            live_mapping: mapping,
            live_settings: settings
        }
    end
  end

  defp version_from_name(name) do
    case Regex.run(~r/_v(\d+)\z/, name) do
      [_, version] -> String.to_integer(version)
      nil -> nil
    end
  end

  # Fetch the current alias group directly from the cluster, bypassing the
  # `WriteTargets` cache - management operations need fresh state.
  defp alias_group(alias_name) do
    {:ok, %{status: 200, body: body}} = Api.get_all_aliases(@policy.opensearch_url())

    WriteTargets.group(body, alias_name)
  end

  @doc ~S"""
  Remove every document from the module's index, leaving the mapping intact.

  `POST /#{index_name}/_delete_by_query`

  Unlike `delete_index!/1`, the index itself survives, so this does not have to be followed
  by a `create_index!/1`. Version conflicts are ignored, and the emptied index is refreshed
  before returning.

  ## Example

      iex> Search.clear_index!(Image)

  """
  @spec clear_index!(schema_module()) :: :ok
  def clear_index!(module) do
    index = @policy.index_for(module)
    body = %{query: %{match_all: %{}}}

    {:ok, %{status: 200}} =
      Api.delete_by_query(@policy.opensearch_url(), prefixed_index_name(index), body)

    :ok
  end

  @doc ~S"""
  Force a refresh of the module's index.

  `POST /#{index_name}/_refresh`

  Indexing is near real-time: documents written by `index_document/2` or `reindex/3` only
  become visible to search on the index's refresh interval, which is 5 seconds unless
  changed in the mapping. This performs that refresh immediately.

  ## Example

      iex> Search.refresh_index!(Image)

  """
  @spec refresh_index!(schema_module()) :: :ok
  def refresh_index!(module) do
    index = @policy.index_for(module)

    {:ok, %{status: 200}} =
      Api.refresh_index(@policy.opensearch_url(), prefixed_index_name(index))

    :ok
  end

  @doc ~S"""
  Update the schema mapping for the module's index name.

  `PUT /#{index_name}/_mapping`

  This is used to add new fields to an existing search mapping. This cannot be used to
  remove fields; removing fields requires recreating the index. The mapping
  version is recorded in `mappings._meta`, so an additive migration updates
  the live version without a rebuild.

  ## Options

  - `version:`, `mapping:` - override the index module's `version/0` and
    `mapping/0`; see `create_index!/2`.

  Raises unless the search engine acknowledges the update.

  ## Example

      iex> Search.update_mapping!(Image)
      :ok

  """
  @spec update_mapping!(schema_module(), Keyword.t()) :: :ok
  def update_mapping!(module, opts \\ []) do
    index = @policy.index_for(module)
    version = Keyword.get(opts, :version, index.version())
    mapping = Keyword.get(opts, :mapping, index.mapping())

    body = %{properties: mapping.mappings.properties, _meta: %{version: version}}

    {:ok, %{status: 200}} =
      Api.update_index_mapping(@policy.opensearch_url(), prefixed_index_name(index), body)

    :ok
  end

  @doc ~S"""
  Add a single document to the index named by the module.

  `PUT /#{index_name}/_doc/#{id}`

  This allows the search engine to query the document.

  Note that indexing is near real-time and requires an index refresh before the document will
  become visible. Unless changed in the mapping, this happens after 5 seconds have elapsed.

  During an index migration the write fans out to every physical index backing
  the alias; resolution can be overridden with the `targets` option. Failures against
  individual physical indices are tolerated (a concurrently deleted old index
  responds 404 while the surviving copy succeeds).

  ## Example

      iex> Search.index_document(%Image{...}, Image)

  """
  @spec index_document(struct(), schema_module(), Keyword.t()) :: any()
  def index_document(doc, module, opts \\ []) do
    index = @policy.index_for(module)
    data = index.as_json(doc)

    for target <- write_targets(index, opts) do
      Api.index_document(@policy.opensearch_url(), target, data, data.id)
    end
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
  @spec delete_document(term(), schema_module(), Keyword.t()) :: any()
  def delete_document(id, module, opts \\ []) do
    index = @policy.index_for(module)

    for target <- write_targets(index, opts) do
      Api.delete_document(@policy.opensearch_url(), target, id)
    end
  end

  @doc """
  Efficiently index a batch of documents in the index named by the module.

  This function is substantially more efficient than running `index_document/2` for
  each instance of a schema struct and can index with hundreds of times the throughput.

  The queryable should be a schema type with its indexing preloads included in
  the query. The options are forwarded to `PhilomenaQuery.Batch.record_batches/2`.

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
  @spec reindex_stream(queryable(), schema_module(), reindex_options()) ::
          Enumerable.t({:ok, integer()})
  def reindex_stream(queryable, module, opts \\ []) do
    max_concurrency = Keyword.get(opts, :max_concurrency, 1)
    index = @policy.index_for(module)

    queryable
    |> Batch.query_batches(Keyword.take(opts, [:batch_size, :id_field]))
    |> Task.async_stream(
      fn query ->
        records = Repo.all(query)

        # Resolved per batch, so a long-running reindex spanning an index
        # migration picks up write-target changes as they happen.
        targets = write_targets(index, opts)

        lines =
          Enum.flat_map(records, fn record ->
            doc = index.as_json(record)

            Enum.flat_map(targets, fn target ->
              [
                %{index: %{_index: target, _id: doc.id}},
                doc
              ]
            end)
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
  the query. The options are forwarded to `PhilomenaQuery.Batch.record_batches/2`.

  Note that indexing is near real-time and requires an index refresh before documents will
  become visible. Unless changed in the mapping, this happens after 5 seconds have elapsed.

  ## Example

      query =
        from i in Image,
          where: i.id < 100_000,
          preload: ^Images.indexing_preloads()

      Search.reindex(query, Image, batch_size: 1024)

  """
  @spec reindex(queryable(), schema_module(), reindex_options()) :: :ok
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

    # Fan out to every physical index explicitly: during a migration the new
    # index is not yet reachable through the alias. Documents not yet bulk
    # loaded into it simply do not match the query there; the bulk pass
    # recomputes them from the database afterwards.
    for target <- write_targets(index, []) do
      Api.update_by_query(@policy.opensearch_url(), target, body)
    end
  end

  @doc ~S"""
  Search the index named by the module.

  `POST /#{index_name}/_search`

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
      Api.search(@policy.opensearch_url(), prefixed_index_name(index), query_body)

    results
  end

  @doc ~S"""
  Given a keyword list of names and search definitions, searches each index with the
  respective body. Results retain the supplied names.

  `POST /_msearch`

  This is more efficient than performing a `search/1` for each index individually.
  Like `search/1`, this returns the raw query results.

  ## Example

      iex> Search.msearch([
      ...>   images: %{module: Image, body: %{query: %{match_all: %{}}}},
      ...>   posts: %{module: Post, body: %{query: %{match_all: %{}}}}
      ...> ])
      %{images: %{"_shards" => ..., "hits" => ...}, posts: %{"_shards" => ..., "hits" => ...}}

  """
  @spec msearch(named_search_definitions()) :: %{atom() => map()}
  def msearch(named_definitions) do
    names = Keyword.keys(named_definitions)
    definitions = Keyword.values(named_definitions)

    msearch_body =
      Enum.flat_map(definitions, fn def ->
        [
          %{index: prefixed_index_name(@policy.index_for(def.module))},
          def.body
        ]
      end)

    {:ok, %{body: results, status: 200}} =
      Api.msearch(@policy.opensearch_url(), msearch_body)

    responses = results["responses"]

    if length(responses) != length(definitions) do
      raise "multi-search returned #{length(responses)} responses for #{length(definitions)} queries"
    end

    Map.new(Enum.zip(names, responses))
  end

  @doc """
  Transforms an index module, query body, and pagination parameters into a query suitable
  for submission to the search engine.

  Any of the following functions may be used for submission:
  - `search_results/1`
  - `msearch_results/1`
  - `search_records/2`
  - `msearch_records/1`
  - `search_records_with_hits/2`
  - `msearch_records_with_hits/1`

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
  Given a keyword list of names and search definitions, submit the queries and return a map of
  names to `m:Scrivener.Page` results.

  The `entries` in the page are a list of tuples of record IDs paired with the hit that generated
  them.

  ## Example

      iex> Search.msearch_results(example: definition)
      %{example: %Scrivener.Page{
          entries: [{1, %{"_id" => "1", ...}}, ...],
          page_number: 1,
          page_size: 25,
          total_entries: 6,
          total_pages: 1
        }}

  """
  @spec msearch_results(named_search_definitions()) :: %{atom() => Scrivener.Page.t()}
  def msearch_results(named_definitions) do
    responses = msearch(named_definitions)

    Map.new(named_definitions, fn {name, definition} ->
      {name, process_results(Map.fetch!(responses, name), definition)}
    end)
  end

  defp load_records_from_results(named_searches) do
    named_definitions =
      Keyword.new(named_searches, fn {name, {definition, _query}} -> {name, definition} end)

    pages = msearch_results(named_definitions)

    Map.new(named_searches, fn {name, {_definition, ecto_query}} ->
      page = Map.fetch!(pages, name)
      {ids, hits} = Enum.unzip(page.entries)

      records =
        ecto_query
        |> where([m], m.id in ^ids)
        |> Repo.all()
        |> Enum.sort_by(&Enum.find_index(ids, fn el -> el == &1.id end))

      {name, %{page | entries: Enum.zip(records, hits)}}
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
    %{default: page} = load_records_from_results(default: {definition, ecto_query})
    page
  end

  @doc """
  Given a keyword list pairing names with `{definition, queryable}` tuples, submit the queries and
  return a map of names to `m:Scrivener.Page` results.

  The `entries` in the page are a list of tuples of schema structs paired with the hit that
  generated them.

  ## Example

      iex> Search.msearch_records_with_hits(example: {definition, preload(Image, :tags)})
      %{example:
        %Scrivener.Page{
          entries: [{%Image{id: 1, ...}, %{"_id" => "1", ...}}, ...],
          page_number: 1,
          page_size: 25,
          total_entries: 6,
          total_pages: 1
        }}

  """
  @spec msearch_records_with_hits(named_record_searches()) :: %{atom() => Scrivener.Page.t()}
  def msearch_records_with_hits(named_searches) do
    load_records_from_results(named_searches)
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
  Given a keyword list pairing names with `{definition, queryable}` tuples, submit the queries and
  return a map of names to `m:Scrivener.Page` results.

  The `entries` in the page are a list of schema structs.

  ## Example

      iex> Search.msearch_records(example: {definition, preload(Image, :tags)})
      %{example:
        %Scrivener.Page{
          entries: [%Image{id: 1, ...}, ...],
          page_number: 1,
          page_size: 25,
          total_entries: 6,
          total_pages: 1
        }}

  """
  @spec msearch_records(named_record_searches()) :: %{atom() => Scrivener.Page.t()}
  def msearch_records(named_searches) do
    Map.new(msearch_records_with_hits(named_searches), fn {name, page} ->
      {records, _hits} = Enum.unzip(page.entries)

      {name, %{page | entries: records}}
    end)
  end

  @doc ~S"""
  Remove multiple documents from the index named by the module using bulk API.

  ## Examples

      iex> Search.delete_documents([1, 2, 3], Image)

  """
  @spec delete_documents([term()], schema_module()) :: any()
  def delete_documents(ids, module) when is_list(ids) do
    index = @policy.index_for(module)
    targets = write_targets(index, [])

    lines = for id <- ids, target <- targets, do: %{delete: %{_index: target, _id: id}}

    Api.bulk(@policy.opensearch_url(), lines)
  end
end
