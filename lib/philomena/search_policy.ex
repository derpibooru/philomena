defmodule Philomena.SearchPolicy do
  alias Philomena.Comments.Comment
  alias Philomena.Comments
  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries
  alias Philomena.Images.Image
  alias Philomena.Images
  alias Philomena.Posts.Post
  alias Philomena.Posts
  alias Philomena.Reports.Report
  alias Philomena.Reports
  alias Philomena.Tags.Tag
  alias Philomena.Tags
  alias Philomena.TagChanges.TagChange
  alias Philomena.TagChanges
  alias Philomena.Filters.Filter
  alias Philomena.Filters
  alias Philomena.Users.User
  alias Philomena.Users

  @type schema_module ::
          Comment | Gallery | Image | Post | Report | Tag | TagChange | Filter | User

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
  def index_for(Comment), do: Comments.SearchIndex
  def index_for(Gallery), do: Galleries.SearchIndex
  def index_for(Image), do: Images.SearchIndex
  def index_for(Post), do: Posts.SearchIndex
  def index_for(Report), do: Reports.SearchIndex
  def index_for(Tag), do: Tags.SearchIndex
  def index_for(TagChange), do: TagChanges.SearchIndex
  def index_for(Filter), do: Filters.SearchIndex
  def index_for(User), do: Users.SearchIndex

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
