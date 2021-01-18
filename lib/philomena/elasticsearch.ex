defmodule Philomena.Elasticsearch do
  alias Philomena.Batch
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

  alias Philomena.Comments.ElasticsearchIndex, as: CommentIndex
  alias Philomena.Galleries.ElasticsearchIndex, as: GalleryIndex
  alias Philomena.Images.ElasticsearchIndex, as: ImageIndex
  alias Philomena.Posts.ElasticsearchIndex, as: PostIndex
  alias Philomena.Reports.ElasticsearchIndex, as: ReportIndex
  alias Philomena.Tags.ElasticsearchIndex, as: TagIndex
  alias Philomena.Filters.ElasticsearchIndex, as: FilterIndex

  defp index_for(Comment), do: CommentIndex
  defp index_for(Gallery), do: GalleryIndex
  defp index_for(Image), do: ImageIndex
  defp index_for(Post), do: PostIndex
  defp index_for(Report), do: ReportIndex
  defp index_for(Tag), do: TagIndex
  defp index_for(Filter), do: FilterIndex

  defp elastic_url do
    Application.get_env(:philomena, :elasticsearch_url)
  end

  def create_index!(module) do
    index = index_for(module)

    Elastix.Index.create(
      elastic_url(),
      index.index_name(),
      index.mapping()
    )
  end

  def delete_index!(module) do
    index = index_for(module)

    Elastix.Index.delete(elastic_url(), index.index_name())
  end

  def update_mapping!(module) do
    index = index_for(module)

    index_name = index.index_name()
    mapping = index.mapping().mappings.properties

    Elastix.Mapping.put(elastic_url(), index_name, "_doc", %{properties: mapping},
      include_type_name: true
    )
  end

  def index_document(doc, module) do
    index = index_for(module)
    data = index.as_json(doc)

    Elastix.Document.index(
      elastic_url(),
      index.index_name(),
      "_doc",
      data.id,
      data
    )
  end

  def delete_document(id, module) do
    index = index_for(module)

    Elastix.Document.delete(
      elastic_url(),
      index.index_name(),
      "_doc",
      id
    )
  end

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
        elastic_url(),
        lines,
        index: index.index_name(),
        httpoison_options: [timeout: 30_000]
      )
    end)
  end

  def update_by_query(module, query_body, set_replacements, replacements) do
    index = index_for(module)

    url =
      elastic_url()
      |> prepare_url([index.index_name(), "_update_by_query"])
      |> append_query_string(%{conflicts: "proceed", wait_for_completion: "false"})

    # Elasticsearch "Painless" scripting language
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

  def search(module, query_body) do
    index = index_for(module)

    {:ok, %{body: results, status_code: 200}} =
      Elastix.Search.search(
        elastic_url(),
        index.index_name(),
        [],
        query_body
      )

    results
  end

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
        elastic_url(),
        "_all",
        [],
        msearch_body
      )

    results["responses"]
  end

  def search_definition(module, elastic_query, pagination_params \\ %{}) do
    page_number = pagination_params[:page_number] || 1
    page_size = pagination_params[:page_size] || 25

    elastic_query =
      Map.merge(elastic_query, %{
        from: (page_number - 1) * page_size,
        size: page_size,
        _source: false,
        track_total_hits: true
      })

    %{
      module: module,
      body: elastic_query,
      page_number: page_number,
      page_size: page_size
    }
  end

  defp process_results(results, definition) do
    time = results["took"]
    count = results["hits"]["total"]["value"]
    entries = Enum.map(results["hits"]["hits"], &{String.to_integer(&1["_id"]), &1})

    Logger.debug("[Elasticsearch] Query took #{time}ms")
    Logger.debug("[Elasticsearch] #{Jason.encode!(definition.body)}")

    %Scrivener.Page{
      entries: entries,
      page_number: definition.page_number,
      page_size: definition.page_size,
      total_entries: count,
      total_pages: div(count + definition.page_size - 1, definition.page_size)
    }
  end

  def search_results(definition) do
    process_results(search(definition.module, definition.body), definition)
  end

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

  def search_records_with_hits(definition, ecto_query) do
    [page] = load_records_from_results([search_results(definition)], [ecto_query])

    page
  end

  def msearch_records_with_hits(definitions, ecto_queries) do
    load_records_from_results(msearch_results(definitions), ecto_queries)
  end

  def search_records(definition, ecto_query) do
    page = search_records_with_hits(definition, ecto_query)
    {records, _hits} = Enum.unzip(page.entries)

    %{page | entries: records}
  end

  def msearch_records(definitions, ecto_queries) do
    Enum.map(load_records_from_results(msearch_results(definitions), ecto_queries), fn page ->
      {records, _hits} = Enum.unzip(page.entries)

      %{page | entries: records}
    end)
  end
end
