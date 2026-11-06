defmodule Philomena.Galleries do
  @moduledoc """
  Gallery creation, presentation, image membership, subscriptions, account
  erasure, and search-index coordination.

  ## Gallery/image locking

  Adding, removing, and reordering images lock every affected image before
  locking the gallery. This hierarchy serializes those operations with image
  hides and merges, which remove or migrate gallery interactions while holding
  the image lock. Reordering locks the submitted image set in ascending ID
  order before acquiring the gallery lock.

  Gallery deletion is a deliberate exception. The gallery must be locked first
  to determine its complete membership, and locking its images afterwards would
  invert the hierarchy. Deletion instead relies on the database cascade to lock
  and remove the gallery's interaction rows.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_write_access: 1]

  alias Philomena.Multi
  alias Philomena.Repo
  alias Philomena.Loader

  alias PhilomenaQuery.Batch
  alias PhilomenaQuery.Search
  alias Philomena.Attribution.Actor
  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries.GalleryPage
  alias Philomena.Galleries.Interaction
  alias Philomena.Galleries.QueryBuilder
  alias Philomena.Galleries.QueryForm
  alias Philomena.Galleries.ReorderForm
  alias Philomena.Galleries
  alias Philomena.IndexWorker
  alias Philomena.Interactions
  alias Philomena.Notifications
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.Images.Search, as: ImageSearch
  alias Philomena.Images.Search.Scope
  alias Philomena.Users.User
  alias Philomena.Reports

  use Philomena.Subscriptions,
    on_delete: :clear_gallery_notification,
    id_name: :gallery_id

  @gallery_selector_limit 100
  @gallery_preloads [:user, thumbnail: [:sources, tags: :aliases]]

  defp load_gallery(actor, gallery_id, action) do
    Loader.fetch_and_authorize(Gallery, actor, action, gallery_id, @gallery_preloads)
  end

  defp last_position(gallery_id) do
    Interaction
    |> where(gallery_id: ^gallery_id)
    |> Repo.aggregate(:max, :position)
  end

  defp notify_gallery(_repo, %{gallery: gallery}) do
    Notifications.broadcast_gallery_image(gallery)
  end

  defp put_reindex_gallery(%Multi{} = multi, step \\ :gallery) do
    Multi.on_commit(multi, fn %{^step => gallery} -> reindex_gallery(gallery) end)
  end

  defp cleanup_gallery(%Gallery{} = gallery) do
    gallery_query = where(Gallery, id: ^gallery.id)

    Interaction
    |> where(gallery_id: ^gallery.id)
    |> Batch.query_batches(batch_size: 1_000, id_field: :image_id)
    |> Enum.each(fn batch_query ->
      Multi.new()
      |> Multi.lock_one(:locked_gallery, gallery_query)
      |> Multi.delete_all(:interactions, select(batch_query, [i], i.image_id))
      |> Multi.update_all(
        :update_gallery,
        fn %{interactions: {count, _image_ids}} ->
          update(gallery_query, inc: [image_count: ^(-count)])
        end,
        []
      )
      |> Multi.on_commit(fn %{interactions: {_count, image_ids}} ->
        Images.reindex_images(image_ids)
      end)
      |> Multi.transact()
    end)
  end

  defp persist_gallery_deletion(%Gallery{} = gallery, %User{} = closing_user) do
    cleanup_gallery(gallery)

    # Deletion must lock the gallery before discovering its members. It cannot
    # then lock the unbounded image set without inverting the image-first
    # hierarchy used by add/remove/reorder and image hide/merge workflows. The
    # gallery FK cascade locks and deletes any raced interaction rows instead.
    gallery_query = where(Gallery, id: ^gallery.id)

    interactions_query =
      Interaction
      |> where(gallery_id: ^gallery.id)
      |> select([i], i.image_id)

    Multi.new()
    |> Multi.lock_one(:locked_gallery, gallery_query)
    |> Multi.delete_all(:interactions, interactions_query)
    |> Reports.put_close_reports(:reports, closing_user, gallery_id: gallery.id)
    |> Multi.delete(:gallery, fn %{locked_gallery: gallery} -> gallery end)
    |> Multi.on_commit(fn %{gallery: gallery} -> unindex_gallery(gallery) end)
    |> Multi.on_commit(fn %{interactions: {_, image_ids}} -> Images.reindex_images(image_ids) end)
    |> Multi.transact()
    |> case do
      {:ok, %{gallery: %Gallery{} = gallery}} ->
        {:ok, gallery}

      {:error, :locked_gallery, :not_found, _changes} ->
        {:error, :not_found}
    end
  end

  defp gallery_image_ids(%Gallery{} = gallery, image_ids) do
    Interaction
    |> where([interaction], interaction.gallery_id == ^gallery.id)
    |> where([interaction], interaction.image_id in ^image_ids)
    |> select([interaction], interaction.image_id)
    |> Repo.all()
  end

  defp position_order(%{order_position_asc: true}), do: [asc: :position]
  defp position_order(_gallery), do: [desc: :position]

  defp persist_reorder_positions(%Gallery{} = gallery, requested_image_ids) do
    # Load the submitted subset in the gallery's current display order.
    affected_interactions =
      Interaction
      |> where(gallery_id: ^gallery.id)
      |> where([i], i.image_id in ^requested_image_ids)
      |> order_by(^position_order(gallery))
      |> Repo.all()

    # If the requested order is [c, a], while the affected rows are currently
    # [a, c] at positions [0, 2], this becomes %{0 => 0, 1 => 2}.
    position_by_current_index =
      affected_interactions
      |> Enum.with_index()
      |> Map.new(fn {interaction, index} -> {index, interaction.position} end)

    # The requested list describes the desired order of the submitted rows:
    # [c, a] becomes %{c => 0, a => 1}.
    requested_index_by_image_id =
      requested_image_ids
      |> Enum.with_index()
      |> Map.new()

    # Pair each affected row's current index with its requested index.
    # a moves to position_by_current_index[1] (2), and c moves to
    # position_by_current_index[0] (0).
    interaction_updates =
      affected_interactions
      |> Enum.with_index()
      |> Enum.flat_map(fn {interaction, current_index} ->
        requested_index = requested_index_by_image_id[interaction.image_id]

        if requested_index != current_index do
          [
            %{
              id: interaction.id,
              gallery_id: interaction.gallery_id,
              image_id: interaction.image_id,
              position: position_by_current_index[requested_index]
            }
          ]
        else
          # Rows already in the requested slot remain unchanged.
          []
        end
      end)

    Repo.insert_all(
      Interaction,
      interaction_updates,
      on_conflict: {:replace, [:position]},
      conflict_target: [:id]
    )

    {:ok, nil}
  end

  defp image_sort_direction(%{order_position_asc: true}), do: :asc
  defp image_sort_direction(_gallery), do: :desc

  defp put_query(list, name, {actor, scope, sort, query}, pagination) do
    if pagination.page_number > 0 do
      {:ok, {definition, _tags}} =
        ImageSearch.search_string(actor, scope, sort, query, pagination: pagination)

      Keyword.put(list, name, {definition, preload(Image, [:sources, tags: :aliases])})
    else
      list
    end
  end

  defp reorder_window(%Actor{} = actor, %Scope{} = scope, %Gallery{} = gallery) do
    query = "gallery_id:#{gallery.id}"
    sort = ImageSearch.gallery_sort(gallery.id, image_sort_direction(gallery))
    params = {actor, scope, sort, query}

    limit = scope.pagination.page_size
    offset = (scope.pagination.page_number - 1) * limit

    # The leading and trailing queries fetch the single images just before and
    # just after this page. With a page size of 1, the image at zero-based
    # index i is on page i + 1.
    #
    # The leading query will not be possible on the first page, so a map key
    # with an empty page is inserted if no search was performed.

    []
    |> put_query(:images, params, scope.pagination)
    |> put_query(:leading, params, %{page_number: offset, page_size: 1})
    |> put_query(:trailing, params, %{page_number: offset + limit + 1, page_size: 1})
    |> Search.msearch_records_with_hits()
    |> Map.put_new(:leading, %Scrivener.Page{})
  end

  defp map_lock_errors(result) do
    case result do
      {:error, _step, :unauthorized, _changes} ->
        {:error, :unauthorized}

      {:error, _step, :not_found, _changes} ->
        {:error, :not_found}
    end
  end

  @doc """
  Builds a change-tracking changeset for a new gallery, on behalf of `actor`.

  Only a signed-in actor authorized to create galleries receives the changeset.

  ## Examples

      iex> new_gallery(actor)
      {:ok, %Ecto.Changeset{}}

      iex> new_gallery(banned_actor)
      {:error, :ban}

  """
  @spec new_gallery(Actor.t()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :unauthorized}
  def new_gallery(%Actor{} = actor) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :new, Gallery) do
      {:ok, Gallery.changeset(%Gallery{})}
    end
  end

  @doc """
  Creates a gallery, on behalf of `actor`.

  ## Examples

      iex> create_gallery(user, gallery_params)
      {:ok, %Gallery{}}

      iex> create_gallery(user, invalid_params)
      {:error, %Ecto.Changeset{}}

      iex> create_gallery(banned_user, invalid_params)
      {:error, :ban}

  """
  @spec create_gallery(Actor.t(), map()) ::
          {:ok, Gallery.t()} | {:error, :ban | :unauthorized | Ecto.Changeset.t()}
  def create_gallery(%Actor{user: user} = actor, attrs) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, Gallery) do
      Multi.new()
      |> Multi.insert(:gallery, Gallery.creation_changeset(%Gallery{}, attrs, user))
      |> put_reindex_gallery()
      |> Multi.transact()
      |> case do
        {:ok, %{gallery: %Gallery{} = gallery}} ->
          {:ok, gallery}

        {:error, :gallery, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Updates the gallery named by `gallery_id`, on behalf of `actor`.

  On success the gallery is updated and reindexed.

  ## Examples

      iex> update_gallery(user, "1", gallery_params)
      {:ok, %Gallery{}}

      iex> update_gallery(user, "1", invalid_params)
      {:error, %Ecto.Changeset{}}

      iex> update_gallery(banned_user, "1", gallery_params)
      {:error, :ban}

      iex> update_gallery(other_user, "1", gallery_params)
      {:error, :unauthorized}

      iex> update_gallery(admin, "999999999", gallery_params)
      {:error, :not_found}

  """
  @spec update_gallery(Actor.t(), Loader.integer_id(), map() | nil) ::
          {:ok, Gallery.t()} | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def update_gallery(%Actor{} = actor, gallery_id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, gallery} <- load_gallery(actor, gallery_id, :update) do
      Multi.new()
      |> Multi.update(:gallery, Gallery.changeset(gallery, attrs))
      |> put_reindex_gallery()
      |> Multi.transact()
      |> case do
        {:ok, %{gallery: %Gallery{} = gallery}} ->
          {:ok, gallery}

        {:error, :gallery, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Deletes the gallery named by `gallery_id`, on behalf of `actor`.

  Loading and authorization follow `update_gallery/3`.

  ## Examples

      iex> delete_gallery(actor, "1")
      {:ok, %Gallery{}}

  """
  @spec delete_gallery(Actor.t(), Loader.integer_id()) ::
          {:ok, Gallery.t()} | {:error, :ban | :unauthorized | :not_found}
  def delete_gallery(%Actor{} = actor, gallery_id) do
    with :ok <- verify_write_access(actor),
         {:ok, gallery} <- load_gallery(actor, gallery_id, :delete) do
      persist_gallery_deletion(gallery, actor.user)
    end
  end

  @doc """
  Loads the gallery named by `gallery_id` for editing, on
  behalf of `actor`, pairing it with a change-tracking changeset for it.

  Loading and authorization otherwise follow `update_gallery/3`, authorizing `:edit`.

  ## Examples

      iex> edit_gallery(user, "1")
      {:ok, {%Gallery{}, %Ecto.Changeset{}}}

      iex> edit_gallery(banned_user, "1")
      {:error, :ban}

      iex> edit_gallery(other_user, "1")
      {:error, :unauthorized}

      iex> edit_gallery(admin, "999999999")
      {:error, :not_found}

  """
  @spec edit_gallery(Actor.t(), Loader.integer_id()) ::
          {:ok, {Gallery.t(), Ecto.Changeset.t()}}
          | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def edit_gallery(%Actor{} = actor, gallery_id) do
    with :ok <- verify_write_access(actor),
         {:ok, gallery} <- load_gallery(actor, gallery_id, :edit) do
      {:ok, {gallery, Gallery.changeset(gallery)}}
    end
  end

  @doc """
  Loads a gallery by ID as a report target on behalf of `actor`.

  Missing and malformed IDs are always not-found. A real gallery the actor may
  not show is unauthorized.

  ## Examples

      iex> load_report_target(actor, "1")
      {:ok, %Gallery{}}
  """
  @spec load_report_target(Actor.t(), Loader.integer_id()) ::
          {:ok, Gallery.t()} | {:error, :unauthorized | :not_found}
  def load_report_target(%Actor{} = actor, gallery_id) do
    load_gallery(actor, gallery_id, :show)
  end

  @doc """
  Runs the gallery listing search `params` describes, returning the record page
  with its thumbnail preloads and a changeset for a new search.

  ## Examples

      iex> list_galleries(actor, %{"title" => "sunset"}, pagination)
      {:ok, %Scrivener.Page{}, %Ecto.Changeset{}}

      iex> list_galleries(actor, %{"include_image" => "abcd"}, pagination)
      {:error, %Ecto.Changeset{}}

  """
  @spec list_galleries(Actor.t(), map(), Search.pagination_params()) ::
          {:ok, Scrivener.Page.t(Gallery.t()), Ecto.Changeset.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :unauthorized}
  def list_galleries(%Actor{} = actor, params, pagination) do
    with :ok <- authorize(actor, :index, Gallery),
         {:ok, query, form} <- QueryBuilder.build_query(params) do
      galleries =
        Gallery
        |> Search.search_definition(query, pagination)
        |> Search.search_records(preload(Gallery, ^@gallery_preloads))

      {:ok, galleries, QueryForm.changeset(form)}
    end
  end

  @doc """
  Searches galleries on behalf of `actor`, with the query string `query_string`
  and `pagination`, sorted by creation time descending.

  An empty or missing `query_string` compiles to a match-none query, returning
  an empty page. Results are preloaded with their creator. Returns
  `{:ok, galleries}`, or `{:error, msg}` when `query_string` fails to compile.

  ## Examples

      iex> query_galleries(user, "title:sunset", pagination)
      {:ok, %Scrivener.Page{}}

      iex> query_galleries(user, ")", pagination)
      {:error, "Imbalanced parentheses."}

  """
  @spec query_galleries(Actor.t(), String.t() | nil, Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t(Gallery.t())} | {:error, :unauthorized | String.t()}
  def query_galleries(%Actor{user: user} = actor, query_string, pagination) do
    with :ok <- authorize(actor, :search, Gallery) do
      case Philomena.Galleries.Query.compile(query_string, user: user) do
        {:ok, query} ->
          galleries =
            Gallery
            |> Search.search_definition(
              %{query: query, sort: %{created_at: :desc}},
              pagination
            )
            |> Search.search_records(preload(Gallery, [:user]))

          {:ok, galleries}

        {:error, msg} ->
          {:error, msg}
      end
    end
  end

  @doc """
  Assembles the `GalleryPage` for the viewer described by `scope`, from
  `gallery_id`.

  The gallery's position order is merged into the scope's parameters so the
  images list, and the previous/next page probes flanking it, run in gallery
  order; interactions and subscription state are computed for the viewer, and
  the viewer's notification for the gallery is cleared as a side effect (so the
  caller must read any notification counts afterwards).

  ## Examples

      iex> show_gallery(actor, user_scope, "1")
      {:ok, %GalleryPage{}}

      iex> show_gallery(actor, user_scope, "999999999")
      {:error, :not_found}

      iex> show_gallery(admin, admin_scope, "999999999")
      {:error, :not_found}

  """
  @spec show_gallery(Actor.t(), Scope.t(), Loader.integer_id()) ::
          {:ok, GalleryPage.t()} | {:error, :unauthorized | :not_found}
  def show_gallery(%Actor{} = actor, %Scope{} = scope, gallery_id) do
    with {:ok, gallery} <- load_gallery(actor, gallery_id, :show) do
      %{images: images, leading: leading, trailing: trailing} =
        reorder_window(actor, scope, gallery)

      watching = subscribed?(gallery, actor.user)
      interactions = Interactions.user_interactions(actor, [images, leading, trailing])
      gallery_images = Enum.concat([leading, images, trailing])

      clear_gallery_notification(gallery, actor.user)

      {:ok,
       %GalleryPage{
         gallery: gallery,
         images: images,
         gallery_images: gallery_images,
         gallery_prev: Enum.any?(leading),
         gallery_next: Enum.any?(trailing),
         interactions: interactions,
         watching: watching
       }}
    end
  end

  @doc """
  Lists up to #{@gallery_selector_limit} of the signed-in `actor`'s galleries,
  most recently updated first, pairing each with whether it already contains
  `image`.

  Anonymous actors receive an empty list. The fixed bound keeps the image-page
  gallery selector from growing without limit.

  ## Examples

      iex> gallery_choices_for_image(actor, image)
      {:ok, [{%Gallery{}, true}, {%Gallery{}, false}]}

      iex> gallery_choices_for_image(anonymous_actor, image)
      {:ok, []}

  """
  @spec gallery_choices_for_image(Actor.t(), Image.t()) ::
          {:ok, [{Gallery.t(), boolean()}]} | {:error, :unauthorized}
  def gallery_choices_for_image(%Actor{user: nil} = actor, %Image{}) do
    with :ok <- authorize(actor, :index, Gallery), do: {:ok, []}
  end

  def gallery_choices_for_image(%Actor{user: user} = actor, %Image{} = image) do
    with :ok <- authorize(actor, :select_for_image, Gallery) do
      choices =
        Gallery
        |> from(as: :gallery)
        |> where(user_id: ^user.id)
        |> join(
          :inner_lateral,
          [],
          _ in subquery(
            Interaction
            |> where([interaction], interaction.image_id == ^image.id)
            |> where([interaction], interaction.gallery_id == parent_as(:gallery).id)
            |> select([interaction], %{exists: count(interaction.id) > 0})
          ),
          on: true
        )
        |> select([g, e], {g, e.exists})
        |> order_by(desc: :updated_at)
        |> limit(^@gallery_selector_limit)
        |> Repo.all()

      {:ok, choices}
    end
  end

  @doc """
  Adds the image named by `image_id` to the gallery named by
  `gallery_id`, on behalf of `actor`.

  The gallery and image are independently loaded and authorized. On success,
  the image is added at the last position, notifications are broadcast, and
  both search documents are queued for reindexing. Adding an existing
  membership returns a gallery changeset error.

  ## Examples

      iex> create_gallery_image(actor, "1", "42")
      {:ok, %Gallery{}}

      iex> create_gallery_image(banned_actor, "1", "42")
      {:error, :ban}

      iex> create_gallery_image(other_actor, "1", "42")
      {:error, :unauthorized}

      iex> create_gallery_image(admin_actor, "999999999", "42")
      {:error, :not_found}

  """
  @spec create_gallery_image(
          actor :: Actor.t(),
          gallery_id :: Loader.integer_id(),
          image_id :: Loader.integer_id()
        ) ::
          {:ok, Gallery.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found}
  def create_gallery_image(%Actor{} = actor, gallery_id, image_id) do
    with :ok <- verify_write_access(actor),
         {:ok, gallery_id} <- Loader.parse_id(gallery_id),
         {:ok, image_id} <- Loader.parse_id(image_id) do
      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image_id))
      |> Multi.lock_one(:locked_gallery, where(Gallery, id: ^gallery_id))
      |> Multi.run(:authorize, fn _repo, %{locked_image: image, locked_gallery: gallery} ->
        with :ok <- authorize(actor, :show, image),
             :ok <- authorize(actor, :add_image, gallery) do
          {:ok, nil}
        end
      end)
      |> Multi.insert(:interaction, fn %{locked_gallery: gallery} ->
        position = (last_position(gallery.id) || -1) + 1

        %Interaction{gallery_id: gallery.id}
        |> Interaction.changeset(%{image_id: image_id, position: position})
      end)
      |> Multi.update(:gallery, fn %{locked_gallery: gallery} ->
        Gallery.add_image_changeset(gallery)
      end)
      |> Multi.run(:notification, &notify_gallery/2)
      |> put_reindex_gallery()
      |> Multi.run(:image, fn _repo, %{locked_image: image} -> {:ok, image} end)
      |> Images.put_reindex_image(:image)
      |> Multi.transact()
      |> case do
        {:ok, %{gallery: %Gallery{} = gallery}} ->
          {:ok, gallery}

        {:error, :interaction, _changeset, %{locked_gallery: gallery}} ->
          {:error, Gallery.add_duplicate_image_error(gallery)}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Removes the image named by `image_id` from the gallery named
  by `gallery_id`, on behalf of `actor`.

  Loading and authorization follow `add_image_to_gallery/3`. The gallery and
  interaction rows are locked in that order. Removing an image that is not in
  the gallery returns `{:error, :not_found}`.

  ## Examples

      iex> delete_gallery_image(actor, "1", "42")
      {:ok, %Gallery{}}

  """
  @spec delete_gallery_image(
          actor :: Actor.t(),
          gallery_id :: Loader.integer_id(),
          image_id :: Loader.integer_id()
        ) ::
          {:ok, Gallery.t()}
          | {:error, :ban | :unauthorized | :not_found}
          | Ecto.Multi.failure()
  def delete_gallery_image(%Actor{} = actor, gallery_id, image_id) do
    with :ok <- verify_write_access(actor),
         {:ok, gallery_id} <- Loader.parse_id(gallery_id),
         {:ok, image_id} <- Loader.parse_id(image_id) do
      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image_id))
      |> Multi.lock_one(:locked_gallery, where(Gallery, id: ^gallery_id))
      |> Multi.run(:authorize, fn _repo, %{locked_image: image, locked_gallery: gallery} ->
        with :ok <- authorize(actor, :show, image),
             :ok <- authorize(actor, :remove_image, gallery) do
          {:ok, nil}
        end
      end)
      |> Multi.lock_one(:locked_interaction, fn %{locked_gallery: gallery} ->
        Interaction
        |> where(gallery_id: ^gallery.id)
        |> where(image_id: ^image_id)
      end)
      |> Multi.delete(:interaction, fn %{locked_interaction: interaction} -> interaction end)
      |> Multi.update(:gallery, fn %{locked_gallery: gallery} ->
        Gallery.remove_image_changeset(gallery)
      end)
      |> put_reindex_gallery()
      |> Multi.run(:image, fn _repo, %{locked_image: image} -> {:ok, image} end)
      |> Images.put_reindex_image(:image)
      |> Multi.transact()
      |> case do
        {:ok, %{gallery: %Gallery{} = gallery}} ->
          {:ok, gallery}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Reorders the gallery named by `gallery_id` to the order given by `image_ids`,
  on behalf of `actor`.

  The IDs may be integers or decimal strings, must be unique, and must all
  belong to the gallery. The list may contain only the images visible on a
  paginated gallery page and may contain at most 250 IDs; omitted memberships
  retain their existing positions.
  Extra, duplicate, or malformed IDs return the rejected reorder changeset.
  Successful reorders return the validated reorder form after the database
  update commits.

  ## Examples

      iex> update_gallery_order(actor, "1", %{image_ids: [3, 1, 2]})
      {:ok, %ReorderForm{}}

  """
  @spec update_gallery_order(Actor.t(), Loader.integer_id(), map()) ::
          {:ok, ReorderForm.t()}
          | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def update_gallery_order(%Actor{} = actor, gallery_id, params) do
    with :ok <- verify_write_access(actor),
         {:ok, gallery_id} <- Loader.parse_id(gallery_id),
         {:ok, reorder_form} <-
           %ReorderForm{}
           |> ReorderForm.changeset(params)
           |> Ecto.Changeset.apply_action(:create) do
      image_query =
        from image in Image,
          where: image.id in ^reorder_form.image_ids,
          select: image.id,
          order_by: [asc: :id]

      Multi.new()
      |> Multi.lock_all(:locked_images, image_query)
      |> Multi.lock_one(:locked_gallery, where(Gallery, id: ^gallery_id))
      |> Multi.run(:authorize, fn _repo, %{locked_gallery: gallery} ->
        with :ok <- authorize(actor, :reorder, gallery) do
          {:ok, nil}
        end
      end)
      |> Multi.run(:reorder_form, fn _repo, %{locked_gallery: gallery} ->
        valid_image_ids = gallery_image_ids(gallery, reorder_form.image_ids)

        reorder_form
        |> ReorderForm.membership_changeset(gallery, valid_image_ids)
        |> Ecto.Changeset.apply_action(:update)
      end)
      |> Multi.run(:reorder, fn _repo, %{locked_gallery: gallery, reorder_form: reorder_form} ->
        persist_reorder_positions(gallery, reorder_form.image_ids)
      end)
      |> Multi.on_commit(fn %{reorder_form: reorder_form} ->
        Images.reindex_images(reorder_form.image_ids)
      end)
      |> Multi.transact()
      |> case do
        {:ok, %{reorder_form: %ReorderForm{} = reorder_form}} ->
          {:ok, reorder_form}

        {:error, :reorder_form, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Clears `user`'s unread notifications for the gallery named by
  `gallery_id`.

  Any authenticated actor may mark a visible gallery read. This personal
  read-state operation is deliberately exempt from the content write-access
  gate. Loading uses the shared member contract, so malformed and missing IDs
  are always not-found.

  ## Examples

      iex> create_gallery_read(user, "1")
      {:ok, %Gallery{}}

      iex> create_gallery_read(user, "nonexistent")
      {:error, :not_found}

  """
  @spec create_gallery_read(Actor.t(), Loader.integer_id()) ::
          {:ok, Gallery.t()} | {:error, :unauthorized | :not_found}
  def create_gallery_read(%Actor{user: user} = actor, gallery_id) do
    with {:ok, gallery} <- load_gallery(actor, gallery_id, :mark_read) do
      clear_gallery_notification(gallery, user)
      {:ok, gallery}
    end
  end

  @doc """
  Subscribes `user` to the gallery named by `gallery_id`.

  Subscription management is deliberately exempt from
  `verify_write_access/1`; gallery visibility and subscription authorization
  still apply.

  ## Examples

      iex> create_gallery_subscription(user, "1")
      {:ok, %Gallery{}}

  """
  @spec create_gallery_subscription(Actor.t(), Loader.integer_id()) ::
          {:ok, Gallery.t()}
          | {:error, :unauthorized | :not_found | Ecto.Changeset.t()}
  def create_gallery_subscription(%Actor{} = actor, gallery_id) do
    with {:ok, gallery} <- load_gallery(actor, gallery_id, :subscribe),
         {:ok, _subscription} <- create_subscription(gallery, actor.user) do
      {:ok, gallery}
    end
  end

  @doc """
  Unsubscribes `user` from the gallery named by `gallery_id`.

  ## Examples

      iex> delete_gallery_subscription(user, "1")
      {:ok, %Gallery{}}

  """
  @spec delete_gallery_subscription(Actor.t(), Loader.integer_id()) ::
          {:ok, Gallery.t()} | {:error, :unauthorized | :not_found}
  def delete_gallery_subscription(%Actor{} = actor, gallery_id) do
    with {:ok, gallery} <- load_gallery(actor, gallery_id, :unsubscribe) do
      # Deletion is idempotent and cannot fail; the hard match crashes if it does.
      {:ok, _subscription} = delete_subscription(gallery, actor.user)
      {:ok, gallery}
    end
  end

  @doc """
  Removes all gallery memberships for an image within `multi`.

  Image hiding composes this operation after taking the image lock. Gallery
  counters and interaction rows therefore change atomically in the caller's
  transaction.

  Affected galleries are reindexed after the transaction commits.
  """
  @spec put_remove_image_interactions(Multi.t(), Image.t()) :: Multi.t()
  def put_remove_image_interactions(%Multi{} = multi, %Image{} = image) do
    galleries =
      Gallery
      |> join(:inner, [g], gi in assoc(g, :interactions), on: gi.image_id == ^image.id)
      |> update(inc: [image_count: -1])
      |> select([g], g.id)

    multi
    |> Multi.update_all(:galleries, galleries, [])
    |> Multi.delete_all(:gallery_interactions, where(Interaction, image_id: ^image.id), [])
    |> Multi.on_commit(fn %{galleries: {_, gallery_ids}} -> reindex_galleries(gallery_ids) end)
  end

  @doc """
  Migrates an image's gallery memberships to another image within `multi`.

  Existing target memberships win; leftover source memberships are deleted and
  affected gallery counters are adjusted. Image merge workflows must hold both
  image locks before composing this operation.

  Affected galleries are reindexed after the transaction commits.
  """
  @spec put_migrate_image_interactions(Multi.t(), Image.t(), Image.t()) :: Multi.t()
  def put_migrate_image_interactions(%Multi{} = multi, %Image{} = source, %Image{} = target) do
    target_gallery_ids =
      Interaction
      |> where(image_id: ^target.id)
      |> select([gi], gi.gallery_id)

    migratable =
      Interaction
      |> where(image_id: ^source.id)
      |> where([gi], gi.gallery_id not in subquery(target_gallery_ids))
      |> update(set: [image_id: ^target.id])
      |> select([gi], gi.gallery_id)

    leftover =
      Interaction
      |> where(image_id: ^source.id)
      |> select([gi], gi.gallery_id)

    multi
    |> Multi.update_all(:migrated_gallery_interactions, migratable, [])
    |> Multi.delete_all(:gallery_interactions, leftover, [])
    |> Multi.run(:galleries, fn repo, %{gallery_interactions: {_count, gallery_ids}} ->
      {count, nil} =
        Gallery
        |> where([g], g.id in ^gallery_ids)
        |> repo.update_all(inc: [image_count: -1])

      {:ok, {count, gallery_ids}}
    end)
    |> Multi.on_commit(fn %{
                            migrated_gallery_interactions: {_, migrated_gallery_ids},
                            galleries: {_, removed_gallery_ids}
                          } ->
      reindex_galleries(Enum.uniq(migrated_gallery_ids ++ removed_gallery_ids))
    end)
  end

  @doc false
  @spec clear_gallery_notification(Gallery.t(), User.t() | nil) :: :ok
  def clear_gallery_notification(%Gallery{} = gallery, user) do
    Notifications.clear_gallery_image(gallery, user)
    :ok
  end

  @doc """
  Updates gallery search indices when a user's name changes.

  ## Examples

      iex> user_name_reindex("old_username", "new_username")
      :ok

  """
  @spec user_name_reindex(String.t(), String.t()) :: term()
  def user_name_reindex(old_name, new_name) do
    data = Galleries.SearchIndex.user_name_update_by_query(old_name, new_name)

    Search.update_by_query(Gallery, data.query, data.set_replacements, data.replacements)
  end

  @doc """
  Queues a gallery for reindexing.

  Adds the gallery to the indexing queue to update its search index.

  ## Examples

      iex> reindex_gallery(gallery)
      %Gallery{}

  """
  @spec reindex_gallery(Gallery.t()) :: Gallery.t()
  def reindex_gallery(%Gallery{} = gallery) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Galleries", "id", [gallery.id]])

    gallery
  end

  @doc """
  Queues multiple galleries for reindexing by their ids.

  ## Examples

      iex> reindex_galleries([1, 2, 3])
      [1, 2, 3]

  """
  @spec reindex_galleries([integer()]) :: [integer()]
  def reindex_galleries([]), do: []

  def reindex_galleries(gallery_ids) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Galleries", "id", gallery_ids])

    gallery_ids
  end

  @doc """
  Removes a gallery from the search index.

  Deletes the gallery's document from the search index.

  ## Examples

      iex> unindex_gallery(gallery)
      %Gallery{}

  """
  @spec unindex_gallery(Gallery.t()) :: Gallery.t()
  def unindex_gallery(%Gallery{} = gallery) do
    Search.delete_document(gallery.id, Gallery)

    gallery
  end

  @doc """
  Returns a list of associations to preload when indexing galleries.

  ## Examples

      iex> indexing_preloads()
      [:subscribers, :user, :interactions]

  """
  @spec indexing_preloads() :: [atom()]
  def indexing_preloads do
    [:subscribers, :user, :interactions]
  end

  @doc """
  Reindexes galleries based on a column condition.

  Updates the search index for all galleries matching the given column condition.
  Used for batch reindexing of galleries.

  ## Examples

      iex> perform_reindex(:id, [1, 2, 3])
      {:ok, [%Gallery{}, ...]}

  """
  @spec perform_reindex(atom(), [term()]) :: term()
  def perform_reindex(column, condition) do
    Gallery
    |> preload(^indexing_preloads())
    |> where([g], field(g, ^column) in ^condition)
    |> Search.reindex(Gallery)
  end
end
