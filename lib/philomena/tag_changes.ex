defmodule Philomena.TagChanges do
  @moduledoc """
  Searchable tag edit history and moderation workflows.
  """

  import Ecto.Query, warn: false
  import Philomena.Authorization, only: [authorize: 3]

  alias Philomena.Attribution.Actor
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.IndexWorker
  alias Philomena.IntegerId
  alias Philomena.Loader
  alias Philomena.ModerationLogs
  alias Philomena.ModerationLogs.Paths
  alias Philomena.Multi
  alias Philomena.Repo
  alias Philomena.TagChangeRevertWorker
  alias Philomena.TagChanges.QueryBuilder
  alias Philomena.TagChanges.QueryForm
  alias Philomena.TagChanges.RevertForm
  alias Philomena.TagChanges.SearchIndex
  alias Philomena.TagChanges.TagChangeTag
  alias Philomena.TagChanges.TagChange
  alias Philomena.TagChanges.TagChangePage
  alias Philomena.Tags
  alias Philomena.Tags.Tag
  alias Philomena.UserFingerprints
  alias Philomena.Users
  alias Philomena.Users.User
  alias PhilomenaQuery.Batch
  alias PhilomenaQuery.Search

  @history_preloads [
    :user,
    image: [:user, :sources, tags: :aliases],
    tag_change_tags: [:tag]
  ]

  defp tag_change_tag_rows(_tag_change, nil, _added), do: []

  defp tag_change_tag_rows(tag_change, tags, added) do
    Enum.map(tags, &%{tag_change_id: tag_change.id, tag_id: &1.id, added: added})
  end

  defp cast_ip(ip) do
    case EctoNetwork.INET.cast(ip) do
      {:ok, ip} ->
        {:ok, ip}

      _error ->
        {:error, :not_found}
    end
  end

  defp cast_fingerprint(fingerprint) when is_binary(fingerprint) do
    fingerprint =
      fingerprint
      |> String.trim()
      |> String.downcase()

    if UserFingerprints.valid_format?(fingerprint) do
      {:ok, fingerprint}
    else
      {:error, :not_found}
    end
  end

  defp cast_fingerprint(_fingerprint), do: {:error, :not_found}

  defp search_tag_changes(
         %Actor{user: user},
         target,
         resource_filter,
         params,
         pagination
       ) do
    with {:ok, body, query_form} <- QueryBuilder.build_query(user, params) do
      filters = List.wrap(resource_filter)
      body = %{body | query: %{bool: %{must: [body.query | filters]}}}

      tag_changes =
        TagChange
        |> Search.search_definition(body, pagination)
        |> Search.search_records(preload(TagChange, ^@history_preloads))

      page = %TagChangePage{
        target: target,
        tag_changes: tag_changes
      }

      {:ok, page, QueryForm.changeset(query_form, user)}
    end
  end

  defp revert_tag_change_ids(ids, attributes) do
    tag_change_query =
      from tag_change in TagChange,
        inner_join: image in assoc(tag_change, :image),
        where: tag_change.id in ^ids and image.hidden_from_users == false,
        order_by: [desc: tag_change.created_at, desc: tag_change.id],
        preload: [tag_change_tags: [:tag, :tag_change]]

    tag_changes = Repo.all(tag_change_query)

    with {:ok, _result} <-
           tag_changes
           |> Enum.flat_map(& &1.tag_change_tags)
           |> revert_tag_change_tags(attributes) do
      {:ok, tag_changes}
    end
  end

  defp revert_tag_change_tags(tag_change_tags, attributes) do
    tag_change_tags
    |> Enum.group_by(& &1.tag_change.image_id)
    |> Enum.map(fn {image_id, instances} ->
      changed_tags =
        instances
        |> Enum.sort_by(&{DateTime.to_unix(&1.tag_change.created_at), &1.tag_change_id})
        |> Enum.map(fn %{tag_id: tag_id, added: added} ->
          %{tag_id: tag_id, added: added}
        end)

      %{
        image_id: image_id,
        tag_changes: changed_tags
      }
    end)
    |> Images.batch_revert(attributes)
  end

  defp put_enqueue_full_revert(%Multi{} = multi, actor, target) do
    attributes = %{
      ip: to_string(actor.ip),
      fingerprint: actor.fingerprint,
      user_id: actor.user.id,
      batch_size: 100
    }

    Multi.on_commit(multi, fn _changes ->
      Exq.enqueue(Exq, "indexing", TagChangeRevertWorker, [
        Map.put(target, :attributes, attributes)
      ])
    end)
  end

  @doc """
  Enqueues a reversion of all tag changes attributed to a user profile.

  Missing profiles return `{:error, :not_found}`.

  ## Examples

      iex> create_user_tag_change_revert(moderator, "some-user")
      {:ok, %User{}}

  """
  @spec create_user_tag_change_revert(Actor.t(), String.t()) ::
          {:ok, User.t()} | {:error, :unauthorized | :not_found | Ecto.Changeset.t()}
  def create_user_tag_change_revert(%Actor{} = actor, slug) do
    with :ok <- authorize(actor, :revert, TagChange),
         {:ok, user} <- Users.load_profile(actor, slug) do
      Multi.new()
      |> put_enqueue_full_revert(actor, %{user_id: user.id})
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        "TagChange.FullRevert:create",
        Paths.profile_path(user),
        "Reverted all tag changes for user #{user.name}"
      )
      |> Multi.transact()
      |> case do
        {:ok, _changes} ->
          {:ok, user}

        error ->
          error
      end
    end
  end

  @doc """
  Enqueues a reversion of all tag changes attributed to an IP address.

  Invalid IP addresses return `{:error, :not_found}`.

  ## Examples

      iex> create_ip_tag_change_revert(moderator, "203.0.113.5")
      {:ok, "203.0.113.5"}

  """
  @spec create_ip_tag_change_revert(Actor.t(), term()) ::
          {:ok, String.t()} | {:error, :unauthorized | :not_found | Ecto.Changeset.t()}
  def create_ip_tag_change_revert(%Actor{} = actor, ip) do
    with :ok <- authorize(actor, :revert, TagChange),
         {:ok, ip} <- cast_ip(ip) do
      ip = to_string(ip)

      Multi.new()
      |> put_enqueue_full_revert(actor, %{ip: ip})
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        "TagChange.FullRevert:create",
        Paths.ip_profile_path(ip),
        "Reverted all tag changes for ip #{ip}"
      )
      |> Multi.transact()
      |> case do
        {:ok, _changes} ->
          {:ok, ip}

        error ->
          error
      end
    end
  end

  @doc """
  Enqueues a reversion of all tag changes attributed to a fingerprint.

  Invalid fingerprints return `{:error, :not_found}`.

  ## Examples

      iex> create_fingerprint_tag_change_revert(moderator, "C123")
      {:ok, "c123"}

  """
  @spec create_fingerprint_tag_change_revert(Actor.t(), term()) ::
          {:ok, String.t()}
          | {:error, :unauthorized | :not_found | Ecto.Changeset.t()}
  def create_fingerprint_tag_change_revert(%Actor{} = actor, fingerprint) do
    with :ok <- authorize(actor, :revert, TagChange),
         {:ok, fingerprint} <- cast_fingerprint(fingerprint) do
      Multi.new()
      |> put_enqueue_full_revert(actor, %{fingerprint: fingerprint})
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        "TagChange.FullRevert:create",
        Paths.fingerprint_profile_path(fingerprint),
        "Reverted all tag changes for fingerprint #{fingerprint}"
      )
      |> Multi.transact()
      |> case do
        {:ok, _changes} ->
          {:ok, fingerprint}

        error ->
          error
      end
    end
  end

  @doc """
  Searches all tag changes visible to `actor`.

  Hidden-image changes are excluded unless the actor may show their images.
  `params` accepts `tcq`, `sf`, and `sd`; invalid search or sort input returns
  a rejected query changeset. The successful result includes the normalized
  query changeset.

  ## Examples

      iex> list_tag_changes(actor, %{"tcq" => "safe"}, page: 1, page_size: 25)
      {:ok, %TagChangePage{target: nil}, changeset}

  """
  @spec list_tag_changes(Actor.t(), map(), Search.pagination_params()) ::
          {:ok, TagChangePage.t(), Ecto.Changeset.t()}
          | {:error, :unauthorized | Ecto.Changeset.t()}
  def list_tag_changes(%Actor{} = actor, params, pagination) do
    with :ok <- authorize(actor, :index, TagChange) do
      search_tag_changes(actor, nil, [], params, pagination)
    end
  end

  @doc """
  Searches tag changes on the image named by `image_id`.

  Images owns target loading and visibility authorization. Malformed and absent
  IDs are not found; a real hidden image forbidden to the actor is unauthorized.

  ## Examples

      iex> list_image_tag_changes(actor, "42", %{}, page: 1, page_size: 25)
      {:ok, %TagChangePage{target: image}, changeset}

      iex> list_image_tag_changes(actor, "missing", %{}, page: 1, page_size: 25)
      {:error, :not_found}

  """
  @spec list_image_tag_changes(
          Actor.t(),
          IntegerId.integer_id(),
          map(),
          Search.pagination_params()
        ) ::
          {:ok, TagChangePage.t(), Ecto.Changeset.t()}
          | {:error, :not_found | :unauthorized | Ecto.Changeset.t()}
  def list_image_tag_changes(%Actor{} = actor, image_id, params, pagination) do
    with {:ok, image} <- Images.load_visible_image(actor, image_id) do
      search_tag_changes(actor, image, %{term: %{image_id: image.id}}, params, pagination)
    end
  end

  @doc """
  Searches tag changes involving the canonical tag named by `slug` or any of
  its aliases.

  Missing tags are not found before OpenSearch is queried.

  ## Examples

      iex> list_tag_tag_changes(actor, "safe", %{}, page: 1, page_size: 25)
      {:ok, %TagChangePage{target: tag}, changeset}

  """
  @spec list_tag_tag_changes(Actor.t(), String.t(), map(), Search.pagination_params()) ::
          {:ok, TagChangePage.t(), Ecto.Changeset.t()}
          | {:error, :not_found | :unauthorized | Ecto.Changeset.t()}
  def list_tag_tag_changes(%Actor{} = actor, slug, params, pagination) when is_binary(slug) do
    with {:ok, tag} <- Tags.load_canonical_tag(actor, slug) do
      tag_ids = [tag.id | Enum.map(tag.aliases, & &1.id)]
      search_tag_changes(actor, tag, %{terms: %{tag_id: tag_ids}}, params, pagination)
    end
  end

  def list_tag_tag_changes(%Actor{}, _slug, _params, _pagination), do: {:error, :not_found}

  @doc """
  Searches tag changes attributed to the active user named by their profile slug.

  Users owns target loading. Ordinary viewers receive only publicly attributed
  changes; actors with identity-metadata access receive the user's true
  attribution, including changes hidden by anonymous upload attribution.

  ## Examples

      iex> list_user_tag_changes(actor, "Somebody", %{}, page: 1, page_size: 25)
      {:ok, %TagChangePage{target: user}, changeset}

  """
  @spec list_user_tag_changes(Actor.t(), String.t(), map(), Search.pagination_params()) ::
          {:ok, TagChangePage.t(), Ecto.Changeset.t()}
          | {:error, :not_found | :unauthorized | Ecto.Changeset.t()}
  def list_user_tag_changes(%Actor{} = actor, slug, params, pagination) do
    with {:ok, user} <- Users.load_profile(actor, slug) do
      user_resource_filter =
        if authorize(actor, :show, :identity_metadata) == :ok do
          %{term: %{true_user_id: user.id}}
        else
          %{term: %{user_id: user.id}}
        end

      search_tag_changes(
        actor,
        user,
        user_resource_filter,
        params,
        pagination
      )
    end
  end

  @doc """
  Searches tag changes attributed to the canonical IP address `ip`.

  Malformed addresses are not found before the shared identity-metadata gate;
  valid addresses with no changes return an empty page.

  ## Examples

      iex> list_ip_tag_changes(moderator, "203.0.113.5", %{}, page: 1, page_size: 25)
      {:ok, %TagChangePage{target: ip}, changeset}

      iex> list_ip_tag_changes(moderator, "not-an-ip", %{}, page: 1, page_size: 25)
      {:error, :not_found}

  """
  @spec list_ip_tag_changes(Actor.t(), String.t(), map(), Search.pagination_params()) ::
          {:ok, TagChangePage.t(), Ecto.Changeset.t()}
          | {:error, :not_found | :unauthorized | Ecto.Changeset.t()}
  def list_ip_tag_changes(%Actor{} = actor, ip, params, pagination) do
    with {:ok, ip} <- cast_ip(ip),
         :ok <- authorize(actor, :show, :identity_metadata) do
      search_tag_changes(actor, ip, %{term: %{ip: to_string(ip)}}, params, pagination)
    end
  end

  @doc """
  Searches tag changes attributed to a canonical browser `fingerprint`.

  The value is normalized and validated through UserFingerprints before the
  shared identity-metadata gate. Valid fingerprints with no changes return an
  empty page.

  ## Examples

      iex> list_fingerprint_tag_changes(moderator, "C123", %{}, page: 1, page_size: 25)
      {:ok, %TagChangePage{target: fingerprint}, changeset}

  """
  @spec list_fingerprint_tag_changes(Actor.t(), String.t(), map(), Search.pagination_params()) ::
          {:ok, TagChangePage.t(), Ecto.Changeset.t()}
          | {:error, :not_found | :unauthorized | Ecto.Changeset.t()}
  def list_fingerprint_tag_changes(%Actor{} = actor, fingerprint, params, pagination) do
    with {:ok, fingerprint} <- cast_fingerprint(fingerprint),
         :ok <- authorize(actor, :show, :identity_metadata) do
      search_tag_changes(
        actor,
        fingerprint,
        %{term: %{fingerprint: fingerprint}},
        params,
        pagination
      )
    end
  end

  @doc """
  Adds tag-change creation to an Images update transaction.

  `image_step` must resolve to an `%Image{}` with added and removed tag lists.
  This helper adds `:tag_change` and `:tag_changes` steps; the latter preserves
  the existing `{added_count, removed_count}` result. Search indexing is
  deferred until the owning transaction commits.

  ## Examples

      iex> put_tag_change(multi, actor)
      %Philomena.Multi{}

  """
  @spec put_tag_change(Multi.t(), Actor.t(), Multi.name()) :: Multi.t()
  def put_tag_change(%Multi{} = multi, %Actor{} = actor, image_step \\ :image) do
    user_id = if actor.user, do: actor.user.id

    multi
    |> Multi.insert(:tag_change, fn %{^image_step => image} ->
      %TagChange{
        image_id: image.id,
        user_id: user_id,
        ip: actor.ip,
        fingerprint: actor.fingerprint
      }
    end)
    |> Multi.run(:tag_changes, fn repo, %{^image_step => image, tag_change: tag_change} ->
      {added_count, nil} =
        repo.insert_all(TagChangeTag, tag_change_tag_rows(tag_change, image.added_tags, true))

      {removed_count, nil} =
        repo.insert_all(TagChangeTag, tag_change_tag_rows(tag_change, image.removed_tags, false))

      {:ok, {added_count, removed_count}}
    end)
    |> Multi.on_commit(fn %{tag_change: tag_change} ->
      Exq.enqueue(Exq, "indexing", IndexWorker, ["TagChanges", "id", [tag_change.id]])
    end)
  end

  @doc """
  Reverts the valid tag-change IDs in `ids` on behalf of `actor`.

  Malformed ID lists return `{:error, changeset}`. Missing IDs and changes on
  hidden images are skipped, making stale or repeated batch submissions safe.
  The selected edits are inverted as one net edit per affected image, so a
  successful reversion creates at most one new tag-change row per image. The
  successful moderation log records the number of loaded changes reverted.

  ## Examples

      iex> create_tag_change_revert(moderator, %{"ids" => ["12", "13"]})
      {:ok, [%TagChange{}, %TagChange{}]}

  """
  @spec create_tag_change_revert(Actor.t(), map()) ::
          {:ok, [TagChange.t()]} | {:error, :unauthorized | Ecto.Changeset.t()}
  def create_tag_change_revert(%Actor{} = actor, params) do
    with :ok <- authorize(actor, :revert, TagChange),
         {:ok, revert_form} <-
           %RevertForm{}
           |> RevertForm.changeset(params)
           |> Ecto.Changeset.apply_action(:create),
         {:ok, tag_changes} <-
           revert_tag_change_ids(revert_form.ids, %{
             ip: actor.ip,
             fingerprint: actor.fingerprint,
             user_id: actor.user.id
           }) do
      ModerationLogs.create_moderation_log(
        actor,
        "TagChange.Revert:create",
        Paths.profile_path(actor.user),
        "Reverted #{length(tag_changes)} tag changes"
      )

      {:ok, tag_changes}
    end
  end

  @doc """
  Reverts a validated worker batch without request authorization or logging.

  The worker owns batching by image ID. All selected edits for an image are
  inverted as one net edit; self-canceling edits produce no new tag-change row.
  Missing IDs and hidden-image changes are skipped; database failures are
  returned to the worker.

  ## Examples

      iex> revert_for_worker([12, 13], attributes)
      {:ok, [%TagChange{}, %TagChange{}]}

  """
  @spec revert_for_worker([IntegerId.integer_id()], map()) ::
          {:ok, [TagChange.t()]} | {:error, Ecto.Changeset.t()}
  def revert_for_worker(ids, attributes) do
    with {:ok, revert_form} <-
           %RevertForm{}
           |> RevertForm.changeset(%{ids: ids})
           |> Ecto.Changeset.apply_action(:create) do
      revert_tag_change_ids(revert_form.ids, attributes)
    end
  end

  @doc """
  Deletes the tag change named by `id` and its moderation audit atomically.

  Loading precedes `:delete` authorization, so malformed and absent IDs are
  always not found while a real forbidden row is unauthorized. Anonymous
  changes use an explicit author label in the log. The search document is
  deleted only after the database transaction commits.

  ## Examples

      iex> delete_tag_change(moderator, "42")
      {:ok, %TagChange{}}

      iex> delete_tag_change(actor, "missing")
      {:error, :not_found}

  """
  @spec delete_tag_change(Actor.t(), IntegerId.integer_id()) ::
          {:ok, TagChange.t()}
          | {:error, :unauthorized | :not_found | Ecto.Changeset.t()}
  def delete_tag_change(%Actor{} = actor, id) do
    with {:ok, tag_change} <-
           TagChange
           |> preload([:user, :image, tag_change_tags: [:tag]])
           |> Loader.fetch_and_authorize(actor, :delete, id) do
      author = if tag_change.user, do: tag_change.user.name, else: "an anonymous user"

      Multi.new()
      |> Multi.delete(:tag_change, tag_change)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        "TagChange:delete",
        Paths.image_path(tag_change.image),
        "Deleted tag change by #{author} containing #{length(tag_change.tag_change_tags)} tags on image #{tag_change.image_id} from history"
      )
      |> Multi.on_commit(fn %{tag_change: tag_change} ->
        Search.delete_document(tag_change.id, TagChange)
      end)
      |> Multi.transact()
      |> case do
        {:ok, %{tag_change: %TagChange{} = tag_change}} ->
          {:ok, tag_change}

        {:error, :tag_change, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Counts tag-change batches and changed tags for an already-loaded image.

  ## Examples

      iex> count_for_image(image)
      {3, 7}

  """
  @spec count_for_image(Image.t()) :: {non_neg_integer(), non_neg_integer()}
  def count_for_image(%Image{id: image_id}) do
    TagChange
    |> where(image_id: ^image_id)
    |> join(:left, [tag_change], tag_change_tag in assoc(tag_change, :tag_change_tags))
    |> select([tag_change, tag], {count(tag_change, :distinct), count(tag)})
    |> Repo.one()
  end

  @doc """
  Builds a lateral query that counts tag-change batches and changed tags for
  the image in the parent query.

  The returned query expects an `:image` parent binding and is intended for
  use with `Ecto.Query.subquery/1`.

  ## Examples

      iex> TagChanges.count_query()
      #Ecto.Query<...>

  """
  @spec count_query() :: Ecto.Query.t()
  def count_query do
    TagChange
    |> where(image_id: parent_as(:image).id)
    |> join(:left, [tag_change], tag_change_tag in assoc(tag_change, :tag_change_tags))
    |> select([tag_change, tag], %{
      change_count: count(tag_change, :distinct),
      tag_count: count(tag)
    })
  end

  @doc """
  Worker service that reverts every tag change selected by `queryable`, batching
  only on image IDs so one image's history cannot straddle a batch boundary.

  ## Examples

      iex> revert_all_for_worker(query, %{batch_size: 100})
      :ok

  """
  @spec revert_all_for_worker(Ecto.Queryable.t(), map()) :: :ok | {:error, term()}
  def revert_all_for_worker(queryable, attributes) do
    batch_size = attributes[:batch_size] || 100
    attributes = Map.delete(attributes, :batch_size)

    queryable
    |> Batch.query_batches(batch_size: batch_size, id_field: :image_id)
    |> Enum.reduce_while(:ok, fn queryable, :ok ->
      queryable
      |> select([tag_change], tag_change.id)
      |> Repo.all()
      |> revert_for_worker(attributes)
      |> case do
        {:ok, _tag_changes} ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Replaces attribution data on a user's tag change history in batches and
  queues the updated rows for reindexing.
  """
  @spec wipe_user_attribution!(integer(), term(), String.t()) :: :ok
  def wipe_user_attribution!(user_id, ip, fingerprint) do
    TagChange
    |> where(user_id: ^user_id)
    |> Batch.query_batches()
    |> Enum.each(fn batch_query ->
      {_count, ids} =
        batch_query
        |> select([tag_change], tag_change.id)
        |> Repo.update_all(set: [ip: ip, fingerprint: fingerprint])

      reindex_tag_changes(ids)
    end)

    :ok
  end

  @doc """
  Adds deletion of tag change tag join table rows represented by `query` to
  `multi`, along with any affected tag change left without tags.

  After commit, the search documents of deleted tag changes are removed and the
  remaining affected tag changes are queued for reindexing.
  """
  @spec put_delete_tag_change_tags(Multi.t(), Multi.name(), Ecto.Query.t()) :: Multi.t()
  def put_delete_tag_change_tags(%Multi{} = multi, step, %Ecto.Query{} = query) do
    tag_change_ids_step = {:tag_change_ids, step}
    empty_tag_changes_step = {:empty_tag_changes, step}

    multi
    |> Multi.all(
      tag_change_ids_step,
      select(query, [tag_change_tag], tag_change_tag.tag_change_id)
    )
    |> Multi.delete_all(step, query)
    |> Multi.delete_all(empty_tag_changes_step, fn %{^tag_change_ids_step => tag_change_ids} ->
      TagChange
      |> from(as: :tag_change)
      |> where([tag_change], tag_change.id in ^tag_change_ids)
      |> where(
        not exists(
          where(
            TagChangeTag,
            [tag_change_tag],
            tag_change_tag.tag_change_id == parent_as(:tag_change).id
          )
        )
      )
      |> select([tag_change], tag_change.id)
    end)
    |> Multi.on_commit(fn %{
                            ^tag_change_ids_step => tag_change_ids,
                            ^empty_tag_changes_step => {_count, empty_ids}
                          } ->
      Enum.each(empty_ids, &Search.delete_document(&1, TagChange))
      reindex_tag_changes(tag_change_ids -- empty_ids)
    end)
  end

  @doc """
  Records tag changes from inserted and deleted image tagging rows in `multi`.

  Images supplies the two prior Multi steps. This function generates the tag
  changes and queues the affected rows after commit.
  """
  @spec put_batch_tag_changes(Multi.t(), Multi.name(), Multi.name(), map()) :: Multi.t()
  def put_batch_tag_changes(%Multi{} = multi, inserted_step, deleted_step, attributes) do
    multi
    |> Multi.run(:batch_tag_changes, fn
      repo,
      %{
        ^inserted_step => {_inserted_count, inserted_taggings},
        ^deleted_step => {_deleted_count, deleted_taggings}
      } ->
        inserted =
          Enum.map(inserted_taggings, fn %{image_id: image_id, tag_id: tag_id} ->
            %{image_id: image_id, tag_id: tag_id, added: true}
          end)

        deleted =
          Enum.map(deleted_taggings, fn [image_id, tag_id] ->
            %{image_id: image_id, tag_id: tag_id, added: false}
          end)

        changes = Enum.concat(inserted, deleted)
        now = DateTime.utc_now(:second)

        # Create tag change batches for every image ID.
        tag_change_rows =
          changes
          |> Enum.uniq_by(& &1.image_id)
          |> Enum.map(fn %{image_id: image_id} ->
            %{
              image_id: image_id,
              user_id: attributes[:user_id],
              ip: attributes[:ip],
              fingerprint: attributes[:fingerprint],
              created_at: now
            }
          end)

        {_count, tag_changes} =
          repo.insert_all(TagChange, tag_change_rows, returning: [:image_id, :id])

        tag_change_ids = Enum.map(tag_changes, & &1.id)
        tag_change_ids_by_image_id = Map.new(tag_changes, &{&1.image_id, &1.id})

        # Create tags belonging to tag changes.
        tag_change_tag_rows =
          Enum.map(changes, fn %{image_id: image_id, tag_id: tag_id, added: added} ->
            %{
              tag_change_id: tag_change_ids_by_image_id[image_id],
              tag_id: tag_id,
              added: added
            }
          end)

        {_count, nil} = repo.insert_all(TagChangeTag, tag_change_tag_rows)

        {:ok, tag_change_ids}
    end)
    |> Multi.on_commit(fn %{batch_tag_changes: tag_change_ids} ->
      reindex_tag_changes(tag_change_ids)
    end)
  end

  @doc """
  Updates tag-change search documents after a user rename.

  ## Examples

      iex> user_name_reindex("old name", "new name")
      :ok

  """
  @spec user_name_reindex(String.t(), String.t()) :: term()
  def user_name_reindex(old_name, new_name) do
    data = SearchIndex.user_name_update_by_query(old_name, new_name)
    Search.update_by_query(TagChange, data.query, data.set_replacements, data.replacements)
  end

  @doc """
  Queues every tag change for worker reindexing.

  ## Examples

      iex> reindex_tag_changes([12, 13])
      [12, 13]

  """
  @spec reindex_tag_changes([integer()]) :: [integer()]
  def reindex_tag_changes(ids) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["TagChanges", "id", ids])
    ids
  end

  @doc """
  Queues every tag change on `image` for indexing and returns the image unchanged.

  Tag-change documents derive their anonymity from the image uploader, so
  changes to the image's uploader or anonymity must call this.

  ## Examples

      iex> reindex_tag_changes_on_image(image)
      %Image{}

  """
  @spec reindex_tag_changes_on_image(Image.t()) :: Image.t()
  def reindex_tag_changes_on_image(%Image{} = image) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["TagChanges", "image_id", [image.id]])
    image
  end

  @doc """
  Returns the association projection required to serialize tag-change search
  documents.

  ## Examples

      iex> indexing_preloads()
      [image: image_query, tag_change_tags: [tag: tag_query], user: user_query]

  """
  @spec indexing_preloads() :: list()
  def indexing_preloads do
    alias_tags_query = select(Tag, [:aliased_tag_id, :name])

    base_tags_query =
      Tag
      |> select([:id, :name])
      |> preload(aliases: ^alias_tags_query)

    image_query = select(Image, [:anonymous, :hidden_from_users, :user_id])

    [
      image: image_query,
      tag_change_tags: [tag: base_tags_query],
      user: select(User, [:name])
    ]
  end

  @doc """
  Worker entry point for reindexing tag changes matching `column` and
  `condition`.

  ## Examples

      iex> perform_reindex(:id, [12, 13])
      :ok

  """
  @spec perform_reindex(atom(), [term()]) :: term()
  def perform_reindex(column, condition) do
    TagChange
    |> preload(^indexing_preloads())
    |> where([tag_change], field(tag_change, ^column) in ^condition)
    |> Search.reindex(TagChange)
  end
end
