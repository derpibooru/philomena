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

  alias Philomena.Polymorphic
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
  @spec recreate_reindex_all_destructive! :: :ok
  def recreate_reindex_all_destructive! do
    @schemas
    |> Stream.map(&recreate_reindex_schema_destructive!/1)
    |> Stream.run()
  end

  @doc """
  Recreate the index corresponding to a schema, and then reindex all of the
  documents within the schema.

  ## Example

      iex> SearchIndexer.recreate_reindex_schema_destructive!(Report)
      :ok

  """
  @spec recreate_reindex_schema_destructive!(schema :: module()) :: :ok
  def recreate_reindex_schema_destructive!(schema) when schema in @schemas do
    Search.delete_index!(schema)
    Search.create_index!(schema)

    reindex_schema(schema)
  end

  @doc """
  Reindex all of the documents within all schemas.

  ## Example

      iex> SearchIndexer.reindex_all()
      :ok

  """
  @spec reindex_all :: :ok
  def reindex_all do
    @schemas
    |> Stream.map(&reindex_schema/1)
    |> Stream.run()
  end

  @doc """
  Reindex all of the documents within a single schema.

  ## Example

      iex> SearchIndexer.reindex_schema(Report)
      :ok

  """
  @spec reindex_schema(schema :: module()) :: :ok
  def reindex_schema(schema)

  def reindex_schema(Report) do
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
      max_concurrency: max_concurrency()
    )
    |> Stream.run()
  end

  def reindex_schema(schema) when schema in @schemas do
    # Normal schemas can simply be reindexed with indexing_preloads
    context = Map.fetch!(@contexts, schema)

    schema
    |> preload(^context.indexing_preloads())
    |> Search.reindex(schema,
      batch_size: @batch_sizes[schema],
      max_concurrency: max_concurrency()
    )
  end

  @spec max_concurrency() :: pos_integer()
  defp max_concurrency do
    System.schedulers_online()
  end
end
