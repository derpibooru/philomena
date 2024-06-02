defmodule Philomena.SearchPolicy do
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

  @type schema_module :: Comment | Gallery | Image | Post | Report | Tag | Filter

  @doc """
  For a given schema module (e.g. `m:Philomena.Images.Image`), return the associated module
  which implements the `SearchIndex` behaviour (e.g. `m:Philomena.Images.SearchIndex`).

  ## Example

      iex> SearchPolicy.index_for(Gallery)
      Philomena.Galleries.SearchIndex

      iex> SearchPolicy.index_for(:foo)
      ** (FunctionClauseError) no function clause matching in Philomena.SearchPolicy.index_for/1

  """
  @spec index_for(schema_module()) :: module()
  def index_for(Comment), do: CommentIndex
  def index_for(Gallery), do: GalleryIndex
  def index_for(Image), do: ImageIndex
  def index_for(Post), do: PostIndex
  def index_for(Report), do: ReportIndex
  def index_for(Tag), do: TagIndex
  def index_for(Filter), do: FilterIndex

  @doc """
  Return the path used to interact with the search engine.

  ## Example

      iex> SearchPolicy.opensearch_url()
      "http://localhost:9200"

  """
  @spec opensearch_url :: String.t()
  def opensearch_url do
    Application.get_env(:philomena, :opensearch_url)
  end
end
