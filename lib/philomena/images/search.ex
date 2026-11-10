defmodule Philomena.Images.Search do
  @moduledoc """
  Search-backed image loading, scoped to a viewer.

  Builds OpenSearch definitions for image listings by combining a query with
  the viewer's compiled filter, the deleted/hidden visibility switches, and the
  requested sort order; loads the tags a tag search names; and finds
  consecutive images for prev/next navigation.

  Query-building functions return `{definition, tags}`: an unexecuted search
  definition plus the raw `Tag` records the query names.
  Definitions are executed with `execute/2`, or batched by callers into
  `PhilomenaQuery.Search.msearch_records/1` alongside definitions for other
  schemas.
  """

  alias Philomena.Images.Image
  alias Philomena.Attribution.Actor
  alias Philomena.Images.Query
  alias Philomena.Images.Search.Scope
  alias Philomena.Repo
  alias Philomena.Tags.Tag
  alias PhilomenaQuery.Search
  import Ecto.Query
  import Philomena.Authorization, only: [authorize: 3]

  @type definition :: Search.search_definition()
  @type query_result :: {definition(), [Tag.t()]}
  @type option :: {:pagination, map()} | {:tag_names, [String.t()]}

  @doc """
  Builds the default image listing query for the viewer.

  Images uploaded less than three minutes ago (or without generated
  thumbnails) are excluded unless the viewer has turned the upload delay off;
  staff have a separate delay preference.

  Returns `{definition, tags}`.
  """
  @spec default_query(Actor.t(), Scope.t(), [option()]) :: query_result()
  # sobelow_skip ["SQL.Query"]
  def default_query(actor, scope, options \\ []) do
    body =
      if delay_home_images?(actor.user),
        do: %{
          bool: %{
            must: [%{range: %{created_at: %{lte: "now-3m"}}}],
            must_not: [%{term: %{thumbnails_generated: false}}]
          }
        },
        else: %{match_all: %{}}

    query(actor, scope, default_sort(), body, options)
  end

  @doc """
  Compiles a search-language string for the viewer and builds its query.

  Returns `{:ok, {definition, tags}}`, or the compiler's `{:error, msg}` for
  a malformed query.
  """
  @spec search_string(Actor.t(), Scope.t(), term(), String.t() | nil, [option()]) ::
          {:ok, query_result()} | {:error, String.t()}
  # sobelow_skip ["SQL.Query"]
  def search_string(
        %Actor{} = actor,
        %Scope{} = scope,
        sort,
        search_string,
        options \\ []
      ) do
    case Query.compile_with_tag_names(search_string, user: actor.user) do
      {:ok, %{query: tree, tag_names: tag_names}} ->
        {:ok, query(actor, scope, sort, tree, Keyword.put(options, :tag_names, tag_names))}

      {:error, _message} = error ->
        error
    end
  end

  @doc """
  Builds a query definition from an already-compiled query body and sort.

  The `:pagination` option overrides the scope's window.

  Returns `{definition, tags}`.
  """
  @spec query(Actor.t(), Scope.t(), term(), map(), [option()]) :: query_result()
  def query(%Actor{} = actor, %Scope{} = scope, sort, body, options \\ []) do
    pagination = Keyword.get(options, :pagination, scope.pagination)
    tags = options |> Keyword.get(:tag_names, []) |> load_tags()
    filters = create_filters(actor, scope)
    {query, sort} = compile_sort(sort, body)

    definition =
      Search.search_definition(
        Image,
        %{
          query: %{
            bool: %{
              must: query,
              must_not: filters
            }
          },
          sort: sort
        },
        pagination
      )

    {definition, tags}
  end

  @doc """
  Executes a definition, returning the record page.

  Records are loaded with the standard listing preloads
  (`[:sources, tags: :aliases]`); pass `:preload` to override. With `hits: true`
  each record is paired with its raw hit, for listings that need sort cursors.
  """
  @spec execute(definition(), Keyword.t()) :: Enumerable.t()
  def execute(definition, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [:sources, tags: :aliases])
    queryable = preload(Image, ^preloads)

    if opts[:hits] do
      Search.search_records_with_hits(definition, queryable)
    else
      Search.search_records(definition, queryable)
    end
  end

  @doc """
  Returns the default sort. Used when no sort is explicitly specified.
  """
  @spec default_sort() :: term()
  def default_sort do
    {{:field, :first_seen_at}, :desc}
  end

  @doc """
  Returns a random sort.
  """
  @spec random_sort() :: term()
  def random_sort do
    {{:random, :rand.uniform(4_294_967_296)}, :desc}
  end

  @doc """
  Returns the sort for a gallery's images in position order.
  """
  @spec gallery_sort(integer(), :asc | :desc) :: term()
  def gallery_sort(gallery_id, direction) do
    {{:gallery, gallery_id}, direction}
  end

  @doc """
  Returns a sort in search relevance order.
  """
  @spec relevance_sort() :: term()
  def relevance_sort() do
    {{:field, :_score}, :desc}
  end

  @doc """
  Returns the exact sort provided by the search scope.
  """
  @spec scope_sort(Scope.t()) :: term()
  def scope_sort(%Scope{sf: sf, sd: sd}) do
    {sf, sd}
  end

  @doc """
  Finds the image next to `image` in the listing the scope's parameters
  describe, for prev/next navigation.

  `compiled_query` is the compiled body of the listing's search query;
  `scope.rel` selects the direction and `scope.sort` carries the sort cursor
  of the current image, when present.

  Returns the `{image, hit}` pair for the neighboring image, or `nil`
  when an error occurred or the end of the sequence was reached.
  """
  @spec find_consecutive(Actor.t(), Scope.t(), Image.t(), map()) :: {Image.t(), map()} | nil
  def find_consecutive(%Actor{} = actor, %Scope{} = scope, %Image{} = image, compiled_query) do
    scope = apply_reverse_navigation(scope)

    consecutive =
      with {:ok, cursor} <- cursor_or_default(image, scope.sf, scope.sort) do
        query = %{
          bool: %{
            must: compiled_query,
            must_not: [%{term: %{id: image.id}} | create_filters(actor, scope)]
          }
        }

        {query, sorts} = compile_sort(scope_sort(scope), query)

        Image
        |> Search.search_definition(
          %{query: query, sort: sorts, search_after: cursor},
          %{page_size: 1}
        )
        |> Search.search_records_with_hits(Image)
        |> Enum.to_list()
      else
        _ -> []
      end

    case consecutive do
      [] -> nil
      [next_image] -> next_image
    end
  end

  defp delay_home_images?(nil), do: true

  defp delay_home_images?(user) when user.role != "user",
    do: user.settings.staff_delay_home_images

  defp delay_home_images?(user), do: user.settings.delay_home_images

  defp create_filters(actor, scope) do
    show_hidden? = authorize(actor, :hide, %Image{}) == :ok
    del = scope.del
    hidden = scope.hidden

    [
      scope.filter
    ]
    |> maybe_show_deleted(show_hidden?, del)
    |> maybe_custom_hide(actor.user, hidden)
    |> hide_non_approved()
  end

  defp maybe_show_deleted(filters, _show_hidden?, "1"),
    do: filters

  defp maybe_show_deleted(filters, false, _param),
    do: [%{term: %{hidden_from_users: true}} | filters]

  defp maybe_show_deleted(filters, true, "only"),
    do: [%{term: %{hidden_from_users: false}} | filters]

  defp maybe_show_deleted(filters, true, "deleted"),
    do: [%{term: %{hidden_from_users: false}}, %{exists: %{field: :duplicate_id}} | filters]

  defp maybe_show_deleted(filters, true, _param),
    do: [%{term: %{hidden_from_users: true}} | filters]

  # Allow users to reverse the effect of hiding images,
  # if desired

  defp maybe_custom_hide(filters, %{id: _id}, true),
    do: filters

  defp maybe_custom_hide(filters, %{id: id}, _param),
    do: [%{term: %{hidden_by_user_ids: id}} | filters]

  defp maybe_custom_hide(filters, _user, _param),
    do: filters

  # Hide all images that aren't approved from all search queries.
  defp hide_non_approved(filters),
    do: [%{term: %{approved: false}} | filters]

  defp load_tags([]), do: []

  defp load_tags(tags) do
    Tag
    |> join(:left, [t], at in Tag, on: t.id == at.aliased_tag_id)
    |> where([t, at], t.name in ^tags or at.name in ^tags)
    |> preload([
      :aliases,
      :aliased_tag,
      :implied_tags,
      :implied_by_tags,
      :dnp_entries,
      :channels,
      public_links: :user,
      hidden_links: :user
    ])
    |> Repo.all()
    |> Enum.uniq_by(& &1.id)
    |> Enum.filter(&is_nil(&1.aliased_tag))
    |> Tag.display_order()
  end

  # Navigation

  defp apply_reverse_navigation(%Scope{} = scope) do
    if scope.rel == :prev do
      case scope.sd do
        :asc -> %{scope | sd: :desc}
        :desc -> %{scope | sd: :asc}
      end
    else
      scope
    end
  end

  defp cursor_or_default(%Image{} = image, sf, sort) do
    if sort do
      {:ok, sort}
    else
      default_cursor(sf, image)
    end
  end

  defp default_cursor(:id, %Image{id: id}) do
    {:ok, [id]}
  end

  defp default_cursor({:field, :first_seen_at}, %Image{first_seen_at: first_seen_at, id: id}) do
    {:ok, [DateTime.to_unix(first_seen_at, :millisecond), id]}
  end

  defp default_cursor(_sort, _image), do: :error

  # Sorting

  defp compile_sort({sf, sd} = _sort, query) do
    case sf do
      :id ->
        {query, [%{id: sd}]}

      {:field, field} ->
        {query, [%{field => sd}, %{id: sd}]}

      {:random, seed} ->
        {
          %{
            function_score: %{
              query: query,
              random_score: %{seed: seed, field: :id},
              boost_mode: :replace
            }
          },
          [%{_score: sd}, %{id: sd}]
        }

      {:gallery, gallery_id} ->
        {
          query,
          [
            %{
              "galleries.position" => %{
                order: sd,
                nested: %{
                  path: :galleries,
                  filter: %{
                    term: %{"galleries.id" => gallery_id}
                  }
                }
              }
            },
            %{id: sd}
          ]
        }
    end
  end
end
