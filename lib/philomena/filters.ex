defmodule Philomena.Filters do
  @moduledoc """
  Image filters, viewer filter selection, and personal tag hide/spoiler settings.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Multi
  alias Philomena.Repo
  alias Philomena.Loader

  alias Philomena.Filters.Filter
  alias Philomena.Filters.ImageFilter
  alias Philomena.Filters.FilterPage
  alias Philomena.Filters.FilterSelection
  alias Philomena.Filters.Query
  alias Philomena.Filters.Visibility
  alias Philomena.Filters
  alias Philomena.Attribution.Actor
  alias Philomena.Schema.TagList
  alias Philomena.Tags
  alias Philomena.Tags.Tag
  alias Philomena.Users
  alias Philomena.Users.User
  alias PhilomenaQuery.Search
  alias Philomena.IndexWorker

  defp ensure_current_filter(%User{current_filter: current_filter} = user) do
    if current_filter do
      current_filter
    else
      filter = default_filter()
      {:ok, _user} = Users.set_current_filter(user, filter)
      filter
    end
  end

  defp filter_for_switch(_actor, nil), do: {:ok, default_filter()}
  defp filter_for_switch(actor, id), do: load_and_authorize_filter(actor, id, :show)

  defp load_and_authorize_filter(actor, id, action, preloads \\ []) do
    Loader.fetch_and_authorize(Filter, actor, action, id, preloads)
  end

  defp authorize_filter_tag(actor, action, current_filter, tag_slug) do
    with :ok <- authorize(actor, action, current_filter) do
      Tag
      |> where(slug: ^tag_slug)
      |> Loader.one_and_authorize(actor, :show)
    end
  end

  defp tags_by_ids(ids) do
    Tag
    |> where([t], t.id in ^ids)
    |> order_by(asc: :name)
    |> Repo.all()
  end

  defp put_reindex_filter(multi, step) do
    Multi.on_commit(multi, fn %{^step => filter} -> reindex_filter(filter) end)
  end

  defp reindex_filter_ids([]), do: []

  defp reindex_filter_ids(filter_ids) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Filters", "id", filter_ids])
    filter_ids
  end

  @doc """
  Returns the default filter.

  This canonical system row is required in every deployment.

  ## Examples

      iex> default_filter()
      %Filter{}

  """
  @spec default_filter() :: Filter.t()
  def default_filter do
    Filter
    |> where(system: true, name: "Default")
    |> Repo.one!()
  end

  @doc """
  Loads the effective current and forced filters for `actor`.

  Signed-in actors use their account associations. When no current filter has
  been selected, the canonical default is persisted first. Anonymous actors may
  select a visible filter through `filter_id`. Malformed, missing, or forbidden
  `filter_id`s fall back to the `default_filter/0`. Anonymous actors cannot have
  a forced filter.

  ## Examples

      iex> load_selected_filters(actor, "42")
      {:ok, %{current_filter: %Filter{}, forced_filter: nil}}

  """
  @spec load_selected_filters(Actor.t(), Loader.integer_id() | nil) ::
          {:ok, %{current_filter: Filter.t(), forced_filter: Filter.t() | nil}}
  def load_selected_filters(%Actor{user: nil} = actor, filter_id) do
    case load_and_authorize_filter(actor, filter_id, :show) do
      {:ok, filter} ->
        {:ok, %{current_filter: filter, forced_filter: nil}}

      _ ->
        {:ok, %{current_filter: default_filter(), forced_filter: nil}}
    end
  end

  def load_selected_filters(%Actor{user: %User{} = user}, _filter_id) do
    user = Repo.preload(user, [:current_filter, :forced_filter])
    current_filter = ensure_current_filter(user)

    {:ok, %{current_filter: current_filter, forced_filter: user.forced_filter}}
  end

  @doc """
  Compiles the effective image-filter policy for `actor`.

  The current filter supplies hidden and spoiler rules; a forced filter adds
  hidden rules. An expression that does not compile for `actor` matches every
  image: an invalid hidden expression hides all images, and an invalid spoiler
  expression spoilers them.
  """
  @spec compile_image_filter(Actor.t(), Filter.t() | nil, Filter.t() | nil) :: ImageFilter.t()
  def compile_image_filter(%Actor{} = actor, current_filter, forced_filter) do
    ImageFilter.compile(actor, current_filter, forced_filter)
  end

  @doc """
  Returns the filters listed for `actor`: the viewer's own paginated filters
  (`nil` for an anonymous visitor) and all system filters, each with `:user`
  preloaded. Authorizes the filter `:index` action before either query.

  ## Examples

      iex> list_filters(actor, pagination)
      {:ok, {%Scrivener.Page{}, [%Filter{}, ...]}}

  """
  @spec list_filters(Actor.t(), Repo.pagination_params()) ::
          {:ok, {Scrivener.Page.t(Filter.t()) | nil, [Filter.t()]}} | {:error, :unauthorized}
  def list_filters(%Actor{user: user} = actor, pagination) do
    with :ok <- authorize(actor, :index, Filter) do
      my_filters =
        if user do
          Filter
          |> where(user_id: ^user.id)
          |> order_by(asc: :id)
          |> preload(:user)
          |> Repo.paginate(pagination)
        else
          nil
        end

      system_filters =
        Filter
        |> where(system: true)
        |> order_by(asc: :id)
        |> preload(:user)
        |> Repo.all()

      {:ok, {my_filters, system_filters}}
    end
  end

  @doc """
  Returns the page of `actor`'s own filters after authorizing `:index_own`.

  Anonymous actors are unauthorized. Results are ordered by descending `:updated_at` and
  paginated by `pagination`.

  ## Examples

      iex> user_filters(actor, pagination)
      {:ok, %Scrivener.Page{}}

  """
  @spec user_filters(Actor.t(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t(Filter.t())} | {:error, :unauthorized}
  def user_filters(%Actor{user: user} = actor, pagination) do
    with :ok <- authorize(actor, :index_own, Filter) do
      {:ok,
       Filter
       |> where(user_id: ^user.id)
       |> order_by(asc: :id)
       |> preload(:user)
       |> Repo.paginate(pagination)}
    end
  end

  @doc """
  Returns the page of system filters for `actor`.

  Authorizes `:index_system` before selecting filters flagged `system: true`,
  ordered by ascending id and paginated by `pagination`.

  ## Examples

      iex> system_filters(actor, pagination)
      {:ok, %Scrivener.Page{}}

  """
  @spec system_filters(Actor.t(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t(Filter.t())} | {:error, :unauthorized}
  def system_filters(%Actor{} = actor, pagination) do
    with :ok <- authorize(actor, :index_system, Filter) do
      {:ok,
       Filter
       |> where(system: true)
       |> order_by(asc: :id)
       |> Repo.paginate(pagination)}
    end
  end

  @doc """
  Loads the filter named by `id` on behalf of `actor`, with `user` preloaded.

  Public and system filters are visible to everyone. Private filters are visible
  to their owner and staff with the corresponding `:show` grant.

  ## Examples

      iex> show_filter(actor, "1")
      {:ok, %Filter{}}

      iex> show_filter(actor, "not-a-number")
      {:error, :not_found}

      iex> show_filter(actor, unowned_private_filter_id)
      {:error, :unauthorized}

  """
  @spec show_filter(Actor.t(), Loader.integer_id()) ::
          {:ok, Filter.t()} | {:error, :not_found | :unauthorized}
  def show_filter(%Actor{} = actor, id) do
    load_and_authorize_filter(actor, id, :show, [:user])
  end

  @doc """
  Runs the filter search that `query_string` describes on behalf of `actor`.

  Compiles `query_string` against the filter search index and restricts results
  to filters the viewer may see. Anonymous visitors see public and system
  filters, members may also see their own private filters, and moderators/admins
  see all filters. Results are sorted by name then descending id, paginated by
  `pagination`, and loaded with `user` preloaded.

  ## Examples

      iex> query_filters(actor, "name:test", pagination)
      {:ok, %Scrivener.Page{}}

      iex> query_filters(actor, "name:(", pagination)
      {:error, "There was an error parsing your query."}

  """
  @spec query_filters(Actor.t(), String.t(), Search.pagination_params()) ::
          {:ok, Scrivener.Page.t(Filter.t())} | {:error, String.t()}
  def query_filters(%Actor{user: user} = actor, query_string, pagination) do
    with :ok <- authorize(actor, :search, Filter),
         {:ok, query} <- Query.compile(query_string, user: user) do
      filters =
        Filter
        |> Search.search_definition(
          %{
            query: %{
              bool: %{
                must: query,
                filter: Visibility.search_filters(actor)
              }
            },
            sort: [
              %{name: :asc},
              %{id: :desc}
            ]
          },
          pagination
        )
        |> Search.search_records(preload(Filter, [:user]))

      {:ok, filters}
    end
  end

  @doc """
  Assembles the filter page named by `id` for `actor`.

  Loads the filter with `user` preloaded, authorizes `:show`, and loads the
  filter's spoilered and hidden tags, each ordered by name.

  ## Examples

      iex> show_filter_page(actor, "1")
      {:ok, %FilterPage{}}

      iex> show_filter_page(actor, "999999999")
      {:error, :not_found}

      iex> show_filter_page(actor, unowned_private_filter_id)
      {:error, :unauthorized}

  """
  @spec show_filter_page(Actor.t(), Loader.integer_id()) ::
          {:ok, FilterPage.t()} | {:error, :not_found | :unauthorized}
  def show_filter_page(%Actor{} = actor, id) do
    with {:ok, filter} <- show_filter(actor, id) do
      {:ok,
       %FilterPage{
         filter: filter,
         spoilered_tags: tags_by_ids(filter.spoilered_tag_ids),
         hidden_tags: tags_by_ids(filter.hidden_tag_ids)
       }}
    end
  end

  @doc """
  Builds the changeset for a new filter on behalf of `actor`.

  Rejects a banned actor, then authorizes `:new` (permitted for any signed-in
  user). When `based_on_id` names a filter the actor may view, the new filter is
  prefilled from it.

  ## Examples

      iex> new_filter(actor, nil)
      {:ok, %Ecto.Changeset{}}

      iex> new_filter(actor, "1")
      {:ok, %Ecto.Changeset{}}

      iex> new_filter(actor, "999999999")
      {:ok, %Ecto.Changeset{data: %Filter{}}}

  """
  @spec new_filter(Actor.t(), Loader.integer_id() | nil) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :unauthorized}
  def new_filter(%Actor{} = actor, based_on_id) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :new, Filter) do
      base_filter =
        case load_and_authorize_filter(actor, based_on_id, :show) do
          {:ok, filter} ->
            filter

          {:error, _reason} ->
            nil
        end

      {:ok,
       base_filter
       |> Filter.based_on()
       |> Filter.changeset(Repo.preload(actor.user, :settings))}
    end
  end

  @doc """
  Loads the filter named by `id` for editing on behalf of `actor`.

  Rejects a banned actor, authorizes `:edit`, and assigns the spoilered and
  hidden tag lists onto the filter.

  ## Examples

      iex> edit_filter(actor, "1")
      {:ok, {%Filter{}, %Ecto.Changeset{}}}

      iex> edit_filter(actor, "999999999")
      {:error, :not_found}

      iex> edit_filter(actor, unowned_filter_id)
      {:error, :unauthorized}

  """
  @spec edit_filter(Actor.t(), Loader.integer_id()) ::
          {:ok, {Filter.t(), Ecto.Changeset.t()}}
          | {:error, :ban | :not_found | :unauthorized}
  def edit_filter(%Actor{} = actor, id) do
    with :ok <- verify_not_banned(actor),
         {:ok, filter} <- load_and_authorize_filter(actor, id, :edit, user: :settings) do
      filter =
        filter
        |> TagList.assign_tag_list(:spoilered_tag_ids, :spoilered_tag_list)
        |> TagList.assign_tag_list(:hidden_tag_ids, :hidden_tag_list)

      {:ok, {filter, Filter.changeset(filter, filter.user)}}
    end
  end

  @doc """
  Switches `actor`'s current filter to the one named by `id`.

  This personal preference update is deliberately exempt from
  `verify_write_access/1`; banned users are permitted to switch filters.

  Authorizes `:switch` before loading. `nil` explicitly selects the canonical default
  filter. Malformed and missing non-nil IDs are not-found.

  For a signed-in actor, the selection is persisted to their account and added
  to recent filters. Anonymous actors must persist the filter through the returned
  Filter struct. Any applicable forced filter is independent and remains unchanged.

  ## Examples

      iex> update_current_filter(actor, "1")
      {:ok, %Filter{}}

      iex> update_current_filter(actor, "999999999")
      {:error, :not_found}

      iex> update_current_filter(actor, nil)
      {:ok, %Filter{name: "Default"}}

  """
  @spec update_current_filter(Actor.t(), Loader.integer_id() | nil) ::
          {:ok, Filter.t()}
          | {:error, :not_found | :unauthorized | Ecto.Changeset.t()}
  def update_current_filter(%Actor{user: user} = actor, id) do
    with :ok <- authorize(actor, :switch, Filter),
         {:ok, filter} <- filter_for_switch(actor, id) do
      if user do
        Users.set_current_filter(user, filter)
      end

      {:ok, filter}
    end
  end

  @doc """
  Creates a filter owned by `actor`.

  Verifies write access, authorizes `:create`, then inserts the filter and queues
  it for reindexing.

  ## Examples

      iex> create_filter(actor, %{field: value})
      {:ok, %Filter{}}

      iex> create_filter(actor, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

      iex> create_filter(anonymous_actor, %{field: value})
      {:error, :unauthorized}

  """
  @spec create_filter(Actor.t(), map()) ::
          {:ok, Filter.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized}
  def create_filter(%Actor{user: user} = actor, attrs \\ %{}) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, Filter) do
      user = Repo.preload(user, :settings)

      filter_changeset =
        %Filter{user_id: user.id}
        |> Filter.creation_changeset(user, attrs)

      Multi.new()
      |> Tags.put_canonicalize_tag_name_sets([
        {:spoilered_filter_tags, Filter.tag_names(filter_changeset, :spoilered_tag_list), []},
        {:hidden_filter_tags, Filter.tag_names(filter_changeset, :hidden_tag_list), []}
      ])
      |> Multi.insert(:filter, fn
        %{
          canonical_tags: %{
            spoilered_filter_tags: spoilered_tags,
            hidden_filter_tags: hidden_tags
          }
        } ->
          Filter.put_tag_ids(
            filter_changeset,
            Enum.map(spoilered_tags, & &1.id),
            Enum.map(hidden_tags, & &1.id)
          )
      end)
      |> put_reindex_filter(:filter)
      |> Multi.transact_with_automatic_retry()
      |> case do
        {:ok, %{filter: %Filter{} = filter}} ->
          {:ok, filter}

        {:error, :filter, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Updates the filter named by `id`, on behalf of `actor`.

  Verifies write access, loads the filter, authorizes `:update`, then applies
  `attrs`.

  ## Examples

      iex> update_filter(actor, "1", %{"name" => "Renamed"})
      {:ok, %Filter{}}

      iex> update_filter(actor, "1", invalid_params)
      {:error, %Ecto.Changeset{}}

      iex> update_filter(actor, "999999999", filter_params)
      {:error, :not_found}

      iex> update_filter(actor, unowned_filter_id, filter_params)
      {:error, :unauthorized}

  """
  @spec update_filter(Actor.t(), Loader.integer_id(), map()) ::
          {:ok, Filter.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :not_found | :unauthorized}
  def update_filter(%Actor{} = actor, id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, filter} <- load_and_authorize_filter(actor, id, :update, user: :settings) do
      filter_changeset = Filter.update_changeset(filter, filter.user, attrs)

      Multi.new()
      |> Tags.put_canonicalize_tag_name_sets([
        {:spoilered_filter_tags, Filter.tag_names(filter_changeset, :spoilered_tag_list), []},
        {:hidden_filter_tags, Filter.tag_names(filter_changeset, :hidden_tag_list), []}
      ])
      |> Multi.update(:filter, fn
        %{
          canonical_tags: %{
            spoilered_filter_tags: spoilered_tags,
            hidden_filter_tags: hidden_tags
          }
        } ->
          Filter.put_tag_ids(
            filter_changeset,
            Enum.map(spoilered_tags, & &1.id),
            Enum.map(hidden_tags, & &1.id)
          )
      end)
      |> put_reindex_filter(:filter)
      |> Multi.transact_with_automatic_retry()
      |> case do
        {:ok, %{filter: %Filter{} = filter}} ->
          {:ok, filter}

        {:error, :filter, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Makes the filter named by `id` public, on behalf of `actor`.

  Verifies write access, loads the filter, authorizes the distinct `:publish`
  action, then makes it public. Publishing an already-public filter is
  idempotent.

  ## Examples

      iex> create_filter_public(actor, "1")
      {:ok, %Filter{}}

      iex> create_filter_public(actor, unowned_filter_id)
      {:error, :unauthorized}

      iex> create_filter_public(actor, "999999999")
      {:error, :not_found}

  """
  @spec create_filter_public(Actor.t(), Loader.integer_id()) ::
          {:ok, Filter.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :not_found | :unauthorized}
  def create_filter_public(%Actor{} = actor, id) do
    with :ok <- verify_write_access(actor),
         {:ok, filter} <- load_and_authorize_filter(actor, id, :publish) do
      filter_changeset = Filter.public_changeset(filter)

      Multi.new()
      |> Multi.update(:filter, filter_changeset)
      |> put_reindex_filter(:filter)
      |> Multi.transact()
      |> case do
        {:ok, %{filter: %Filter{} = filter}} ->
          {:ok, filter}

        {:error, :filter, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Deletes the filter named by `id`, on behalf of `actor`.

  Verifies write access, loads the filter, authorizes `:delete`, then deletes it.
  A filter referenced as a user's current or forced filter returns a rejected
  changeset and cannot be deleted.

  ## Examples

      iex> delete_filter(actor, "1")
      {:ok, %Filter{}}

      iex> delete_filter(actor, "999999999")
      {:error, :not_found}

      iex> delete_filter(actor, unowned_filter_id)
      {:error, :unauthorized}

  """
  @spec delete_filter(Actor.t(), Loader.integer_id()) ::
          {:ok, Filter.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :not_found | :unauthorized}
  def delete_filter(%Actor{} = actor, id) do
    with :ok <- verify_write_access(actor),
         {:ok, filter} <- load_and_authorize_filter(actor, id, :delete) do
      filter_changeset = Filter.deletion_changeset(filter)

      Multi.new()
      |> Multi.delete(:filter, filter_changeset)
      |> Multi.on_commit(fn %{filter: filter} -> Search.delete_document(filter.id, Filter) end)
      |> Multi.transact()
      |> case do
        {:ok, %{filter: %Filter{} = filter}} ->
          {:ok, filter}

        {:error, :filter, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Returns `actor`'s grouped recent and personal filter choices.

  Authorizes `:index_own` before querying. Anonymous actors are unauthorized.

  ## Examples

      iex> recent_and_user_filters(actor)
      {:ok,
       %FilterSelection{
         recent_filters: [%Filter{}, ...],
         user_filters: [%Filter{}, ...]
       }}

  """
  @spec recent_and_user_filters(Actor.t()) :: {:ok, FilterSelection.t()} | {:error, :unauthorized}
  def recent_and_user_filters(%Actor{user: user} = actor) do
    with :ok <- authorize(actor, :index_own, Filter) do
      recent_filter_ids =
        [user.current_filter_id | user.recent_filter_ids]
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.take(10)

      positions =
        recent_filter_ids
        |> Enum.with_index()
        |> Map.new()

      user_filter_query =
        Filter
        |> select([f], %{struct(f, [:id, :name]) | recent: false})
        |> where(user_id: ^user.id)
        |> order_by(asc: :id)
        |> limit(10)

      recent_filter_query =
        Filter
        |> select([f], %{struct(f, [:id, :name]) | recent: true})
        |> where([f], f.id in ^recent_filter_ids)

      {recent_filters, user_filters} =
        recent_filter_query
        |> union_all(^user_filter_query)
        |> Repo.all()
        |> Enum.split_with(& &1.recent)

      {:ok,
       %FilterSelection{
         user_filters: user_filters,
         recent_filters: Enum.sort_by(recent_filters, &Map.fetch!(positions, &1.id))
       }}
    end
  end

  @doc """
  Adds the tag named by `tag_slug` to `filter`'s hidden tags on behalf
  of `actor`.

  Rejects a banned actor or one without a fingerprint, authorizes `:hide_tag`
  on the loaded filter, safely loads the tag, and authorizes the tag for
  `:show`. System filters and filters owned by someone else cannot be changed.

  ## Examples

      iex> create_filter_hide(actor, filter, tag_slug)
      {:ok, %Filter{}}

      iex> create_filter_hide(banned_actor, filter, tag_slug)
      {:error, :ban}

      iex> create_filter_hide(actor, filter, unknown_tag_slug)
      {:error, :not_found}

      iex> create_filter_hide(actor, unowned_filter, tag_slug)
      {:error, :unauthorized}

  """
  @spec create_filter_hide(Actor.t(), Filter.t(), String.t()) ::
          {:ok, Filter.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :not_found | :unauthorized}
  def create_filter_hide(%Actor{} = actor, %Filter{} = filter, tag_slug) do
    with :ok <- verify_write_access(actor),
         {:ok, tag} <- authorize_filter_tag(actor, :hide_tag, filter, tag_slug) do
      Multi.new()
      |> Tags.put_canonicalize_tag_name_sets([{:tag, [tag.name], []}])
      |> Multi.update(:filter, fn %{canonical_tags: %{tag: [tag]}} ->
        tag_ids = Enum.uniq([tag.id | filter.hidden_tag_ids])

        Filter.hidden_tags_changeset(filter, tag_ids)
      end)
      |> put_reindex_filter(:filter)
      |> Multi.transact_with_automatic_retry()
      |> case do
        {:ok, %{filter: %Filter{} = filter}} ->
          {:ok, filter}

        {:error, :filter, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Removes the tag named by `tag_slug` from `filter`'s hidden tags on behalf
  of `actor`.

  Rejects a banned actor or one without a fingerprint, authorizes `:unhide_tag`
  on the loaded filter, safely loads the tag, and authorizes the tag for
  `:show`. System filters and filters owned by someone else cannot be changed.

  ## Examples

      iex> delete_filter_hide(actor, filter, tag_slug)
      {:ok, %Filter{}}

      iex> delete_filter_hide(banned_actor, filter, tag_slug)
      {:error, :ban}

      iex> delete_filter_hide(actor, filter, unknown_tag_slug)
      {:error, :not_found}

      iex> delete_filter_hide(actor, unowned_filter, tag_slug)
      {:error, :unauthorized}

  """
  @spec delete_filter_hide(Actor.t(), Filter.t(), String.t()) ::
          {:ok, Filter.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :not_found | :unauthorized}
  def delete_filter_hide(%Actor{} = actor, %Filter{} = filter, tag_slug) do
    with :ok <- verify_write_access(actor),
         {:ok, tag} <- authorize_filter_tag(actor, :unhide_tag, filter, tag_slug) do
      Multi.new()
      |> Tags.put_canonicalize_tag_name_sets([{:tag, [tag.name], []}])
      |> Multi.update(:filter, fn %{canonical_tags: %{tag: [tag]}} ->
        tag_ids = filter.hidden_tag_ids -- [tag.id]

        Filter.hidden_tags_changeset(filter, tag_ids)
      end)
      |> put_reindex_filter(:filter)
      |> Multi.transact_with_automatic_retry()
      |> case do
        {:ok, %{filter: %Filter{} = filter}} ->
          {:ok, filter}

        {:error, :filter, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Adds the tag named by `tag_slug` to `filter`'s spoilered tags on behalf
  of `actor`.

  Rejects a banned actor or one without a fingerprint, authorizes `:spoiler_tag`
  on the loaded filter, safely loads the tag, and authorizes the tag for
  `:show`. System filters and filters owned by someone else cannot be changed.

  ## Examples

      iex> create_filter_spoiler(actor, filter, tag_slug)
      {:ok, %Filter{}}

      iex> create_filter_spoiler(banned_actor, filter, tag_slug)
      {:error, :ban}

      iex> create_filter_spoiler(actor, filter, unknown_tag_slug)
      {:error, :not_found}

      iex> create_filter_spoiler(actor, unowned_filter, tag_slug)
      {:error, :unauthorized}

  """
  @spec create_filter_spoiler(Actor.t(), Filter.t(), String.t()) ::
          {:ok, Filter.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :not_found | :unauthorized}
  def create_filter_spoiler(%Actor{} = actor, %Filter{} = filter, tag_slug) do
    with :ok <- verify_write_access(actor),
         {:ok, tag} <- authorize_filter_tag(actor, :spoiler_tag, filter, tag_slug) do
      Multi.new()
      |> Tags.put_canonicalize_tag_name_sets([{:tag, [tag.name], []}])
      |> Multi.update(:filter, fn %{canonical_tags: %{tag: [tag]}} ->
        tag_ids = Enum.uniq([tag.id | filter.spoilered_tag_ids])

        Filter.spoilered_tags_changeset(filter, tag_ids)
      end)
      |> put_reindex_filter(:filter)
      |> Multi.transact_with_automatic_retry()
      |> case do
        {:ok, %{filter: %Filter{} = filter}} ->
          {:ok, filter}

        {:error, :filter, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Removes the tag named by `tag_slug` from `filter`'s spoilered tags on behalf
  of `actor`.

  Rejects a banned actor or one without a fingerprint, authorizes `:unspoiler_tag`
  on the loaded filter, safely loads the tag, and authorizes the tag for
  `:show`. System filters and filters owned by someone else cannot be changed.

  ## Examples

      iex> delete_filter_spoiler(actor, filter, tag_slug)
      {:ok, %Filter{}}

      iex> delete_filter_spoiler(banned_actor, filter, tag_slug)
      {:error, :ban}

      iex> delete_filter_spoiler(actor, filter, unknown_tag_slug)
      {:error, :not_found}

      iex> delete_filter_spoiler(actor, unowned_filter, tag_slug)
      {:error, :unauthorized}

  """
  @spec delete_filter_spoiler(Actor.t(), Filter.t(), String.t()) ::
          {:ok, Filter.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :not_found | :unauthorized}
  def delete_filter_spoiler(%Actor{} = actor, %Filter{} = filter, tag_slug) do
    with :ok <- verify_write_access(actor),
         {:ok, tag} <- authorize_filter_tag(actor, :unspoiler_tag, filter, tag_slug) do
      Multi.new()
      |> Tags.put_canonicalize_tag_name_sets([{:tag, [tag.name], []}])
      |> Multi.update(:filter, fn %{canonical_tags: %{tag: [tag]}} ->
        tag_ids = filter.spoilered_tag_ids -- [tag.id]

        Filter.spoilered_tags_changeset(filter, tag_ids)
      end)
      |> put_reindex_filter(:filter)
      |> Multi.transact_with_automatic_retry()
      |> case do
        {:ok, %{filter: %Filter{} = filter}} ->
          {:ok, filter}

        {:error, :filter, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Replaces a tag ID in hidden and spoilered filter arrays within `multi`.

  Tag aliasing composes this function so failed updates roll back with
  the alias transaction.
  """
  @spec put_replace_tag_references(Multi.t(), Multi.name(), Multi.name(), integer(), integer()) ::
          Multi.t()
  def put_replace_tag_references(%Multi{} = multi, hidden_step, spoilered_step, old_id, new_id) do
    hidden_filters =
      Filter
      |> where([f], fragment("? @> ARRAY[?]::integer[]", f.hidden_tag_ids, ^old_id))
      |> update([f],
        set: [
          hidden_tag_ids: fragment("array_replace(?, ?, ?)", f.hidden_tag_ids, ^old_id, ^new_id)
        ]
      )

    spoilered_filters =
      Filter
      |> where([f], fragment("? @> ARRAY[?]::integer[]", f.spoilered_tag_ids, ^old_id))
      |> update([f],
        set: [
          spoilered_tag_ids:
            fragment("array_replace(?, ?, ?)", f.spoilered_tag_ids, ^old_id, ^new_id)
        ]
      )

    hidden_ids_step = {:reindex_filter_ids, hidden_step}
    spoilered_ids_step = {:reindex_filter_ids, spoilered_step}

    multi
    |> Multi.all(hidden_ids_step, select(exclude(hidden_filters, :update), [f], f.id))
    |> Multi.all(spoilered_ids_step, select(exclude(spoilered_filters, :update), [f], f.id))
    |> Multi.update_all(hidden_step, hidden_filters, [])
    |> Multi.update_all(spoilered_step, spoilered_filters, [])
    |> Multi.on_commit(fn %{^hidden_ids_step => hidden_ids, ^spoilered_ids_step => spoilered_ids} ->
      reindex_filter_ids(Enum.uniq(hidden_ids ++ spoilered_ids))
    end)
  end

  @doc """
  Updates filter indexes when a user's name changes.

  ## Examples

      iex> user_name_reindex("old_name", "new_name")
      [update_result, ...]

  """
  @spec user_name_reindex(String.t(), String.t()) :: [term()]
  def user_name_reindex(old_name, new_name) do
    data = Filters.SearchIndex.user_name_update_by_query(old_name, new_name)

    Search.update_by_query(Filter, data.query, data.set_replacements, data.replacements)
  end

  @doc """
  Queues a single filter for search index updates.
  Returns the filter struct unchanged, for use in a pipeline.

  ## Examples

      iex> reindex_filter(filter)
      %Filter{}

  """
  @spec reindex_filter(Filter.t()) :: Filter.t()
  def reindex_filter(%Filter{} = filter) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Filters", "id", [filter.id]])

    filter
  end

  @doc """
  Returns a list of associations to preload when indexing filters.

  ## Examples

      iex> indexing_preloads()
      [:user]

  """
  @spec indexing_preloads() :: list()
  def indexing_preloads do
    [:user]
  end

  @doc """
  Performs a search reindex operation on filters matching the given criteria.

  `column` is supplied by the trusted worker registry, not request input.

  ## Examples

      iex> perform_reindex(:id, [1, 2, 3])
      :ok

  """
  @spec perform_reindex(atom(), [term()]) :: :ok
  def perform_reindex(column, condition) do
    Filter
    |> preload(^indexing_preloads())
    |> where([f], field(f, ^column) in ^condition)
    |> Search.reindex(Filter)
  end
end
