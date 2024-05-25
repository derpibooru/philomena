defmodule PhilomenaQuery.Search do
  @moduledoc """
  Low-level search engine interaction.

  This module generates and delivers search bodies to the OpenSearch backend.

  Note that before an index can be used to index or query documents, a call to
  `create_index!/1` must be made. When setting up an application, or dealing with data loss
  in the search engine, you must call `create_index!/1` before running an indexing task.
  """

  alias PhilomenaQuery.Batch
  alias Philomena.Repo
  require Logger
  import Ecto.Query
  import Elastix.HTTP

  alias Philomena.Comments.Comment
  alias Philomena.Galleries.Gallery
  alias Philomena.Images.Image
  alias Philomena.Posts.Post
  alias Philomena.Reports.Report
  alias Philomena.Tags.Tag
  alias Philomena.Filters.Filter

  alias Philomena.Comments.SearchIndex, as: CommentIndex
  alias Philomena.Galleries.SearchIndex, as: GalleryIndex
  alias Philomena.Images.SearchIndex, as: ImageIndex
  alias Philomena.Posts.SearchIndex, as: PostIndex
  alias Philomena.Reports.SearchIndex, as: ReportIndex
  alias Philomena.Tags.SearchIndex, as: TagIndex
  alias Philomena.Filters.SearchIndex, as: FilterIndex

  defp index_for(Comment), do: CommentIndex
  defp index_for(Gallery), do: GalleryIndex
  defp index_for(Image), do: ImageIndex
  defp index_for(Post), do: PostIndex
  defp index_for(Report), do: ReportIndex
  defp index_for(Tag), do: TagIndex
  defp index_for(Filter), do: FilterIndex

  defp opensearch_url do
    Application.get_env(:philomena, :opensearch_url)
  end

  @type index_module :: module()
  @type queryable :: any()
  @type query_body :: map()

  @type replacement :: %{
          path: [String.t()],
          old: term(),
          new: term()
        }

  @type search_definition :: %{
          module: index_module(),
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
  @spec create_index!(index_module()) :: any()
  def create_index!(module) do
    index = index_for(module)

    Elastix.Index.create(
      opensearch_url(),
      index.index_name(),
      index.mapping()
    )
  end

  @doc ~S"""
  Delete the index with the module's index name.

  `DELETE /#{index_name}`

  This undoes the effect of `create_index!/1` and removes the index permanently, deleting
  all indexed documents within.

  ## Example

      iex> Search.delete_index!(Image)

  """
  @spec delete_index!(index_module()) :: any()
  def delete_index!(module) do
    index = index_for(module)

    Elastix.Index.delete(opensearch_url(), index.index_name())
  end

  @doc ~S"""
  Update the schema mapping for the module's index name.

  `PUT /#{index_name}/_mapping`

  This is used to add new fields to an existing search mapping. This cannot be used to
  remove fields; removing fields requires recreating the index.

  ## Example

      iex> Search.update_mapping!(Image)

  """
  @spec update_mapping!(index_module()) :: any()
  def update_mapping!(module) do
    index = index_for(module)

    index_name = index.index_name()
    mapping = index.mapping().mappings.properties

    Elastix.Mapping.put(opensearch_url(), index_name, "_doc", %{properties: mapping},
      include_type_name: true
    )
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
  @spec index_document(struct(), index_module()) :: any()
  def index_document(doc, module) do
    index = index_for(module)
    data = index.as_json(doc)

    Elastix.Document.index(
      opensearch_url(),
      index.index_name(),
      "_doc",
      data.id,
      data
    )
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
  @spec delete_document(term(), index_module()) :: any()
  def delete_document(id, module) do
    index = index_for(module)

    Elastix.Document.delete(
      opensearch_url(),
      index.index_name(),
      "_doc",
      id
    )
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

      Search.reindex(query, Image, batch_size: 5000)

  """
  @spec reindex(queryable(), index_module(), Batch.batch_options()) :: []
  def reindex(queryable, module, opts \\ []) do
    index = index_for(module)

    Batch.record_batches(queryable, opts, fn records ->
      lines =
        Enum.flat_map(records, fn record ->
          doc = index.as_json(record)

          [
            %{index: %{_index: index.index_name(), _id: doc.id}},
            doc
          ]
        end)

      Elastix.Bulk.post(
        opensearch_url(),
        lines,
        index: index.index_name(),
        httpoison_options: [timeout: 30_000]
      )
    end)
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
  @spec update_by_query(index_module(), query_body(), [replacement()], [replacement()]) :: any()
  def update_by_query(module, query_body, set_replacements, replacements) do
    index = index_for(module)

    url =
      opensearch_url()
      |> prepare_url([index.index_name(), "_update_by_query"])
      |> append_query_string(%{conflicts: "proceed", wait_for_completion: "false"})

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
      Jason.encode!(%{
        script: %{
          source: script,
          params: %{
            set_replacements: set_replacements,
            replacements: replacements
          }
        },
        query: query_body
      })

    {:ok, %{status_code: 200}} = Elastix.HTTP.post(url, body)
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
  @spec search(index_module(), query_body()) :: map()
  def search(module, query_body) do
    index = index_for(module)

    {:ok, %{body: results, status_code: 200}} =
      Elastix.Search.search(
        opensearch_url(),
        index.index_name(),
        [],
        query_body
      )

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
          %{index: index_for(def.module).index_name()},
          def.body
        ]
      end)

    {:ok, %{body: results, status_code: 200}} =
      Elastix.Search.search(
        opensearch_url(),
        "_all",
        [],
        msearch_body
      )

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
  @spec search_definition(index_module(), query_body(), pagination_params()) ::
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
    Logger.debug("[Search] #{Jason.encode!(definition.body)}")

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
