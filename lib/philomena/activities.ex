defmodule Philomena.Activities do
  @moduledoc """
  The site homepage: the recent, top-scoring, watched, featured, comment,
  stream, and topic strips it assembles for a viewer.
  """

  import Ecto.Query, only: [preload: 2]
  import Philomena.Authorization, only: [authorize: 3]

  alias Philomena.Activities.FrontPage
  alias Philomena.Attribution.Actor
  alias Philomena.Channels
  alias Philomena.Comments
  alias Philomena.Comments.Comment
  alias Philomena.Filters.Filter
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.Images.Search, as: ImageSearch
  alias Philomena.Images.Search.Scope
  alias Philomena.Interactions
  alias Philomena.Topics
  alias PhilomenaQuery.Search

  @strip_size 6
  @image_preloads [:sources, tags: :aliases]
  @comment_preloads [:user, image: @image_preloads]

  defp multi_search(images, top_scoring, comments, nil) do
    Search.msearch_records(
      images: {images, preload(Image, ^@image_preloads)},
      top_scoring: {top_scoring, preload(Image, ^@image_preloads)},
      comments: {comments, preload(Comment, ^@comment_preloads)}
    )
    |> Map.put(:watched, nil)
  end

  defp multi_search(images, top_scoring, comments, watched) do
    Search.msearch_records(
      images: {images, preload(Image, ^@image_preloads)},
      top_scoring: {top_scoring, preload(Image, ^@image_preloads)},
      comments: {comments, preload(Comment, ^@comment_preloads)},
      watched: {watched, preload(Image, ^@image_preloads)}
    )
  end

  defp watched_definition(%Actor{user: nil}, _scope), do: {:ok, nil}

  defp watched_definition(%Actor{} = actor, scope) do
    with {:ok, {definition, _tags}} <-
           ImageSearch.search_string(
             actor,
             scope,
             ImageSearch.default_sort(),
             "my:watched",
             pagination: %{scope.pagination | page_number: 1}
           ) do
      {:ok, definition}
    end
  end

  defp search_definitions(%Actor{} = actor, %Scope{} = scope, %Filter{} = filter) do
    {images_definition, _tags} =
      ImageSearch.default_query(actor, scope, pagination: %{scope.pagination | page_number: 1})

    {top_scoring_definition, _tags} =
      ImageSearch.query(
        actor,
        scope,
        {{:field, :wilson_score}, :desc},
        %{range: %{first_seen_at: %{gt: "now-3d"}}},
        pagination: %{page_number: :rand.uniform(6), page_size: 4}
      )

    comments_definition =
      Comments.comment_search_definition(
        actor,
        filter,
        %{range: %{created_at: %{gt: "now-1w"}}},
        pagination: %{page_number: 1, page_size: 6},
        show_hidden: false
      )

    case watched_definition(actor, scope) do
      {:ok, watched_definition} ->
        {images_definition, top_scoring_definition, comments_definition, watched_definition}

      _error ->
        {images_definition, top_scoring_definition, comments_definition, nil}
    end
  end

  defp load_search_sections({images, top_scoring, comments, watched}) do
    multi_search(images, top_scoring, comments, watched)
  end

  defp load_featured_image(actor, scope) do
    include_hidden? = scope.hidden == true

    case Images.show_featured_image(actor, include_hidden?) do
      {:ok, image} -> image
      {:error, :not_found} -> nil
    end
  end

  defp assemble_front_page(actor, scope, definitions, show_nsfw_channels?) do
    sections = load_search_sections(definitions)
    featured_image = load_featured_image(actor, scope)
    topics = Topics.list_front_page_topics(actor, @strip_size)
    streams = Channels.list_front_page_channels(actor, show_nsfw_channels?, @strip_size)

    interactions =
      Interactions.user_interactions(actor, [
        sections.images,
        sections.top_scoring,
        sections.watched,
        featured_image
      ])

    %FrontPage{
      images: sections.images,
      top_scoring: sections.top_scoring,
      comments: sections.comments,
      watched: sections.watched,
      featured_image: featured_image,
      streams: streams,
      topics: topics,
      interactions: interactions
    }
  end

  @doc """
  Assembles the homepage for `actor` using the image-search state in `scope`.

  `scope` retains the compiled filter, pagination, and display parameters for
  for the images strip, top scoring strip, and optional watched strip. `filter`
  supplies hidden tags for the recent comments strip, and `show_nsfw_channels?`
  controls the channel strip.

  All search queries execute as one multi-search. Anonymous actors receive no
  watched strip.

  ## Examples

      iex> show_activity(anonymous_actor, scope, filter, false)
      {:ok, %FrontPage{watched: nil}}

      iex> show_activity(actor, scope, filter, true)
      {:ok, %FrontPage{watched: %Scrivener.Page{}}}

  """
  @spec show_activity(Actor.t(), Scope.t(), Filter.t(), boolean()) ::
          {:ok, FrontPage.t()} | {:error, :unauthorized}
  def show_activity(
        %Actor{} = actor,
        %Scope{} = scope,
        %Filter{} = filter,
        show_nsfw_channels?
      )
      when is_boolean(show_nsfw_channels?) do
    with :ok <- authorize(actor, :show, FrontPage) do
      definitions = search_definitions(actor, scope, filter)
      {:ok, assemble_front_page(actor, scope, definitions, show_nsfw_channels?)}
    end
  end
end
