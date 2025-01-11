defmodule Philomena.SearchIndexer do
  alias PhilomenaQuery.Batch
  alias PhilomenaQuery.Search

  alias Philomena.Comments
  alias Philomena.Comments.Comment
  alias Philomena.Filters
  alias Philomena.Filters.Filter
  alias Philomena.Galleries
  alias Philomena.Galleries.Gallery
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.Posts
  alias Philomena.Posts.Post
  alias Philomena.Reports
  alias Philomena.Reports.Report
  alias Philomena.Tags
  alias Philomena.Tags.Tag

  alias Philomena.Maintenance
  alias Philomena.Polymorphic
  alias Philomena.Repo
  import Ecto.Query

  @schemas [
    Comment,
    Filter,
    Gallery,
    Image,
    Post,
    Report,
    Tag
  ]

  @contexts %{
    Comment => Comments,
    Filter => Filters,
    Gallery => Galleries,
    Image => Images,
    Post => Posts,
    Report => Reports,
    Tag => Tags
  }

  @batch_sizes %{
    Comment => 2048,
    Filter => 2048,
    Gallery => 1024,
    Image => 32,
    Post => 2048,
    Report => 128,
    Tag => 2048
  }

  @doc """
  Recreate the index corresponding to all schemas, and then reindex all of the
  documents within.

  ## Example

      iex> SearchIndexer.recreate_reindex_all_destructive!()
      :ok

  """
  @spec recreate_reindex_all_destructive!(opts :: Keyword.t()) :: :ok
  def recreate_reindex_all_destructive!(opts \\ []) do
    @schemas
    |> Stream.map(&recreate_reindex_schema_destructive!(&1, opts))
    |> Stream.run()
  end

  @doc """
  Recreate the index corresponding to a schema, and then reindex all of the
  documents within the schema.

  ## Example

      iex> SearchIndexer.recreate_reindex_schema_destructive!(Report)
      :ok

  """
  @spec recreate_reindex_schema_destructive!(schema :: module(), opts :: Keyword.t()) :: :ok
  def recreate_reindex_schema_destructive!(schema, opts \\ []) when schema in @schemas do
    Search.delete_index!(schema)
    Search.create_index!(schema)

    reindex_schema(schema, opts)
  end

  @doc """
  Reindex all of the documents within all schemas.

  ## Example

      iex> SearchIndexer.reindex_all()
      :ok

  """
  @spec reindex_all(opts :: Keyword.t()) :: :ok
  def reindex_all(opts \\ []) do
    @schemas
    |> Stream.map(&reindex_schema(&1, opts))
    |> Stream.run()
  end

  @doc """
  Reindex all of the documents within a single schema.

  ## Example

      iex> SearchIndexer.reindex_schema(Report)
      :ok

  """
  @spec reindex_schema(schema :: module(), opts :: Keyword.t()) :: :ok
  def reindex_schema(schema, opts \\ []) do
    maintenance = Keyword.get(opts, :maintenance, true)

    if maintenance do
      query = limit(schema, 1)
      min = Repo.one(order_by(query, asc: :id)).id
      max = Repo.one(order_by(query, desc: :id)).id

      schema
      |> reindex_schema_impl(opts)
      |> Maintenance.log_progress(inspect(schema), min, max)
    else
      schema
      |> reindex_schema_impl(opts)
      |> Stream.run()
    end
  end

  @spec reindex_schema_impl(schema :: module(), opts :: Keyword.t()) ::
          Enumerable.t({:ok, integer()})
  defp reindex_schema_impl(schema, opts)

  defp reindex_schema_impl(Report, opts) do
    # Reports currently require handling for their polymorphic nature
    Report
    |> preload([:user, :admin])
    |> Batch.record_batches(batch_size: @batch_sizes[Report])
    |> Task.async_stream(
      fn records ->
        records
        |> Polymorphic.load_polymorphic(reportable: [reportable_id: :reportable_type])
        |> Enum.map(&Search.index_document(&1, Report))
      end,
      timeout: :infinity,
      max_concurrency: max_concurrency(opts)
    )
  end

  defp reindex_schema_impl(schema, opts) when schema in @schemas do
    # Normal schemas can simply be reindexed with indexing_preloads
    context = Map.fetch!(@contexts, schema)

    schema
    |> preload(^context.indexing_preloads())
    |> Search.reindex_stream(schema,
      batch_size: @batch_sizes[schema],
      max_concurrency: max_concurrency(opts)
    )
  end

  @spec max_concurrency(opts :: Keyword.t()) :: pos_integer()
  defp max_concurrency(opts) do
    Keyword.get(opts, :max_concurrency, System.schedulers_online())
  end
end
