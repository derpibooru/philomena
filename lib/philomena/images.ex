defmodule Philomena.Images do
  @moduledoc """
  Image browsing, uploads, metadata, moderation, interactions, and indexing.

  Request-facing operations accept an actor and load image locators before
  authorizing the requested action. Worker and cross-context services are
  named separately from that controller boundary.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  require Logger

  alias Philomena.Multi
  alias Philomena.Repo

  alias PhilomenaQuery.Search
  alias Philomena.ThumbnailWorker
  alias Philomena.ImagePurgeWorker
  alias Philomena.DuplicateReports
  alias Philomena.DnpEntries
  alias Philomena.Images.Image
  alias Philomena.Images.Filtering
  alias Philomena.Images.Uploader
  alias Philomena.Images.Tagging
  alias Philomena.Images.Thumbnailer
  alias Philomena.Images.Source
  alias Philomena.Images.SourceInputForm
  alias Philomena.Images.SourceDiffer
  alias Philomena.Images.TagDiffer
  alias Philomena.Images.TagInputForm
  alias Philomena.Images.BatchTagForm
  alias Philomena.Images.VoteForm
  alias Philomena.Images.Subscription
  alias Philomena.Images
  alias Philomena.IntegerId
  alias Philomena.IndexWorker
  alias Philomena.Loader
  alias Philomena.RateLimiter
  alias Philomena.Attribution.Actor
  alias Philomena.ModerationLogs
  alias Philomena.ModerationLogs.Paths
  alias Philomena.ImageFeatures.ImageFeature
  alias Philomena.ImageVotes
  alias Philomena.ImageHides
  alias Philomena.ImageFaves
  alias Philomena.SourceChanges
  alias Philomena.TagChanges
  alias Philomena.TagChanges.Limits
  alias Philomena.Tags
  alias Philomena.UserStatistics
  alias Philomena.Tags.Tag
  alias Philomena.Notifications
  alias Philomena.Interactions
  alias Philomena.Reports
  alias Philomena.Comments
  alias Philomena.Galleries
  alias Philomena.Images.ImagePage
  alias Philomena.Images.Query, as: ImageQuery
  alias Philomena.Images.Search, as: ImageSearch
  alias Philomena.Images.Search.Scope
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.Users
  alias Philomena.Users.User
  alias PhilomenaWeb.Api.Json.ImageView
  alias PhilomenaWeb.Endpoint
  alias PhilomenaQuery.Batch

  @source_update_window 5
  @tag_update_window 5
  @batch_tag_size 1_000

  use Philomena.Subscriptions,
    on_delete: :clear_image_notification,
    id_name: :image_id

  ## Shared locators

  defp load_image_member(%Actor{} = actor, action, image_id, preloads \\ []) do
    Loader.fetch_and_authorize(Image, actor, action, image_id, preloads)
  end

  ## Query helpers

  defp maybe_exclude_viewer_hides(query, %Actor{user: nil}, _include_hidden?), do: query
  defp maybe_exclude_viewer_hides(query, %Actor{}, true), do: query

  defp maybe_exclude_viewer_hides(query, %Actor{user: user}, false) do
    where(
      query,
      [image],
      fragment(
        "NOT EXISTS(SELECT 1 FROM image_hides WHERE image_id = ? AND user_id = ?)",
        image.id,
        ^user.id
      )
    )
  end

  defp custom_ordering?(%{sf: sf}), do: sf not in [:id, {:field, :first_seen_at}]

  defp maybe_jump_to_last_page(
         %Actor{
           user: %{
             settings: %{comments_newest_first: false, comments_always_jump_to_last: true}
           }
         } = actor,
         image,
         scrivener
       ) do
    Keyword.merge(scrivener, page: Comments.last_comment_page(actor, image, scrivener))
  end

  defp maybe_jump_to_last_page(_actor, _image, scrivener), do: scrivener

  ## Event broadcasting

  defp broadcast_image_create(image) do
    Endpoint.broadcast!(
      "firehose",
      "image:create",
      ImageView.render("show.json", %{image: image, interactions: []})
    )
  end

  defp broadcast_image_update(image) do
    Endpoint.broadcast!(
      "firehose",
      "image:update",
      ImageView.render("show.json", %{image: image, interactions: []})
    )
  end

  defp broadcast_description_update(image, old_description) do
    Endpoint.broadcast!(
      "firehose",
      "image:description_update",
      %{image_id: image.id, added: image.description, removed: old_description}
    )

    broadcast_image_update(image)
  end

  defp broadcast_source_update(image, added, removed) do
    Endpoint.broadcast!(
      "firehose",
      "image:source_update",
      %{image_id: image.id, added: [added], removed: [removed]}
    )

    broadcast_image_update(image)
  end

  defp broadcast_tag_update(image, added, removed) do
    Endpoint.broadcast!(
      "firehose",
      "image:tag_update",
      %{
        image_id: image.id,
        added: Enum.map(added, & &1.name),
        removed: Enum.map(removed, & &1.name)
      }
    )

    broadcast_image_update(image)
  end

  defp broadcast_image_merge(image, duplicate_of_image) do
    Endpoint.broadcast!(
      "firehose",
      "image:merge",
      %{
        image: ImageView.render("image.json", %{image: image}),
        duplicate_of_image: ImageView.render("image.json", %{image: duplicate_of_image})
      }
    )
  end

  defp broadcast_batch_update(image_ids, added_tags, removed_tags) do
    Endpoint.broadcast!(
      "firehose",
      "image:batch_tag_update",
      %{
        image_ids: image_ids,
        added: Enum.map(added_tags, & &1.name),
        removed: Enum.map(removed_tags, & &1.name)
      }
    )
  end

  ## Moderation and lifecycle

  defp put_hide_image(multi, changeset, image, user) do
    multi
    |> Multi.update(:image, changeset)
    |> Reports.put_close_reports(:reports, user, image_id: image.id)
    |> Multi.run(:tags, fn _repo, %{image: image} ->
      image = Repo.preload(image, :tags, force: true)
      {:ok, image.tags}
    end)
    |> Tags.put_image_count_delta(
      :tag_image_counts,
      fn %{tags: tags} -> Enum.map(tags, & &1.id) end,
      -1
    )
    |> Multi.on_commit(fn %{image: image} ->
      spawn(fn ->
        Thumbnailer.hide_thumbnails(image, image.hidden_image_key)
        purge_files(image, image.hidden_image_key)
      end)

      Comments.reindex_comments_on_image(image)
      reindex_image(image)
    end)
  end

  ## Metadata editing

  defp put_lock_image(%Multi{} = multi, %Actor{} = actor, image_id, action, preloads) do
    image_query =
      Image
      |> where(id: ^image_id)
      |> preload(^preloads)

    multi
    |> Multi.lock_one(:locked_image, image_query)
    |> Multi.run(:authorize, fn _repo, %{locked_image: image} ->
      with :ok <- authorize(actor, action, image) do
        {:ok, nil}
      end
    end)
  end

  defp map_lock_errors(result) do
    case result do
      {:error, :locked_image, :not_found, _changes} ->
        {:error, :not_found}

      {:error, :authorize, :unauthorized, _changes} ->
        {:error, :unauthorized}
    end
  end

  defp update_loaded_sources(%Image{} = image, %Actor{} = actor, %SourceInputForm{} = form) do
    %{added: added_sources, removed: removed_sources} =
      SourceDiffer.diff_inputs(form.old_sources, form.sources)

    Multi.new()
    |> Multi.reserve_action(
      fn -> RateLimiter.record_action(actor, :source_update, @source_update_window) end,
      fn -> RateLimiter.rollback_action(actor, :source_update) end
    )
    |> put_lock_image(actor, image.id, :edit_metadata, [:sources])
    |> Multi.run(:image, fn repo, %{locked_image: image} ->
      changeset = Image.source_changeset(image, added_sources, removed_sources)

      if Image.meaningful_source_update?(changeset) do
        repo.update(changeset)
      else
        {:error, :no_change}
      end
    end)
    |> SourceChanges.put_record_image_changes(actor)
    |> UserStatistics.put_increment(actor.user, :metadata_updates_count)
    |> put_reindex_image(:image)
    |> Multi.on_commit(fn %{image: %{added_sources: added, removed_sources: removed} = image} ->
      image = Repo.preload(image, [:user, :sources, tags: :aliases])
      broadcast_source_update(image, added, removed)
    end)
    |> Multi.transact()
    |> case do
      {:error, :action_reservation, :rate_limited, _changes} ->
        {:error, :rate_limited}

      {:ok, %{image: %Image{} = image}} ->
        {:ok, image}

      {:error, :image, :no_change, _changes} ->
        {:error, :no_change}

      {:error, :image, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}

      error ->
        map_lock_errors(error)
    end
  end

  defp update_loaded_tags(%Image{} = image, %Actor{} = actor, %TagInputForm{} = form) do
    %{added: added_tag_names, removed: removed_tag_names} =
      TagDiffer.diff_inputs(
        form.old_tag_input,
        form.tag_input
      )

    Multi.new()
    |> Multi.reserve_action(
      fn -> RateLimiter.record_action(actor, :tag_update, @tag_update_window) end,
      fn -> RateLimiter.rollback_action(actor, :tag_update) end
    )
    |> put_lock_image(actor, image.id, :edit_metadata, [:tags, :locked_tags])
    |> Tags.put_canonicalize_tag_name_sets([
      {:removed_tags, removed_tag_names, []},
      {:added_tags, added_tag_names, allow_insert_new?: true, expand_implications?: true}
    ])
    |> Multi.run(:image, fn
      repo,
      %{
        locked_image: image,
        canonical_tags: %{added_tags: added_tags, removed_tags: removed_tags}
      } ->
        changeset = Image.tag_changeset(image, added_tags, removed_tags, image.locked_tags)

        if Image.meaningful_tag_update?(changeset) do
          repo.update(changeset)
        else
          {:error, :no_change}
        end
    end)
    |> Multi.run(:check_limits, fn _repo, %{image: image} ->
      record_tag_change_limits(image, actor)
    end)
    |> Multi.on_rollback(fn
      %{check_limits: {tag_changed_count, rating_changed_count}} ->
        %Actor{ip: ip, user: user} = actor
        Limits.rollback_action(user, ip, tag_changed_count, rating_changed_count)

      _ ->
        :ok
    end)
    |> TagChanges.put_tag_change(actor)
    |> Tags.put_image_tag_count_changes()
    |> UserStatistics.put_increment(actor.user, :metadata_updates_count)
    |> put_reindex_image(:image)
    |> Multi.on_commit(fn %{image: %{added_tags: added, removed_tags: removed} = image} ->
      image = Repo.preload(image, [:user, :sources, tags: :aliases])
      Comments.reindex_comments_on_image(image)
      broadcast_tag_update(image, added, removed)
    end)
    |> Multi.transact_with_automatic_retry()
    |> case do
      {:error, :action_reservation, :rate_limited, _changes} ->
        {:error, :rate_limited}

      {:ok, %{image: %Image{} = image}} ->
        {:ok, Repo.preload(image, :tags, force: true)}

      {:error, :image, :no_change, _changes} ->
        {:error, :no_change}

      {:error, :image, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}

      {:error, :check_limits, _reason, _changes} ->
        {:error, :rate_limited}

      error ->
        map_lock_errors(error)
    end
  end

  defp record_tag_change_limits(image, %Actor{ip: ip, user: user}) do
    tag_changed_count = length(image.added_tags) + length(image.removed_tags)
    rating_changed_count = if(image.ratings_changed, do: 1, else: 0)

    case Limits.record_action(user, ip, tag_changed_count, rating_changed_count) do
      :ok -> {:ok, {tag_changed_count, rating_changed_count}}
      error -> error
    end
  end

  ## Forms and uploads

  defp image_interaction_allowed?(%Actor{user: nil}, _image), do: false
  defp image_interaction_allowed?(_actor, %Image{hidden_from_users: true}), do: false

  defp image_interaction_allowed?(actor, image) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :vote, image),
         :ok <- Filtering.verify_not_forced(actor, image) do
      true
    else
      _error -> false
    end
  end

  defp comment_changeset_for(_actor, %Image{hidden_from_users: true}), do: nil

  defp comment_changeset_for(actor, image) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :create_comment, image),
         :ok <- Filtering.verify_not_forced(actor, image) do
      Comments.new_comment_changeset()
    else
      _error -> nil
    end
  end

  defp image_changeset_for(actor, image, action) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, action, image),
         :ok <- Filtering.verify_not_forced(actor, image) do
      change_image(%{image | sources: sources_for_edit(image.sources)})
    else
      _error -> nil
    end
  end

  defp uploader_changeset_for(actor, image) do
    case authorize(actor, :show, :identity_metadata) do
      :ok ->
        image_changeset_for(actor, image, :update_uploader)

      _error ->
        nil
    end
  end

  defp sources_for_edit([]), do: [%Source{}]
  defp sources_for_edit(sources), do: sources

  defp async_upload(image, upload) do
    {:ok, upload_pid} =
      Task.Supervisor.start_child(Philomena.ImageUploadSupervisor, fn ->
        # Make sure task will finish before VM exit
        Process.flag(:trap_exit, true)

        # Wait to be freed up by the caller
        receive do
          :ready -> nil
        end

        # Start trying to upload
        try_upload(image, 0)
      end)

    # Give the upload to the linked process
    Plug.Upload.give_away(upload.path, upload_pid, self())

    # Free up the linked process
    send(upload_pid, :ready)

    :ok
  end

  defp try_upload(image, retry_count) when retry_count < 100 do
    try do
      Uploader.persist_upload(image)
      repair_image(image)
    rescue
      e ->
        Logger.error("Upload failed: #{inspect(e)} [try ##{retry_count}]")
        Process.sleep(5000)
        try_upload(image, retry_count + 1)
    end
  end

  defp try_upload(image, retry_count) do
    Logger.error("Aborting upload of #{image.id} after #{retry_count} retries")
  end

  ## Approval and verification

  defp maybe_approve_image(changeset, nil), do: changeset

  defp maybe_approve_image(changeset, %User{verified: false, role: "user"}), do: changeset

  defp maybe_approve_image(changeset, _user) do
    Image.approve_changeset(changeset)
  end

  defp put_approval_steps(%Multi{} = multi) do
    multi
    |> UserStatistics.put_increment(
      fn %{image: image} ->
        if image.approved, do: image.user_id
      end,
      :images_count
    )
    |> Multi.merge(fn
      %{image: %{approved: true, user_id: user_id}} when user_id != nil ->
        put_suggest_user_verification(Multi.new(), user_id)

      _changes ->
        Multi.new()
    end)
  end

  defp put_suggest_user_verification(%Multi{} = multi, user_id) do
    multi
    |> Multi.one(:verification_candidate, where(User, id: ^user_id))
    |> Multi.merge(fn
      %{verification_candidate: %{images_count: 5, verified: false}} ->
        # This deliberately fires only at the fifth approved image so later
        # uploads cannot create duplicate verification reports. Users who cross
        # the threshold through maintenance updates are handled manually rather
        # than adding an existence query to every approval transaction.
        Reports.put_create_system_report(
          Multi.new(),
          "Verification",
          "User has uploaded enough approved images to be considered for verification.",
          :reported_user_id,
          user_id
        )

      _changes ->
        Multi.new()
    end)
  end

  ## Media processing

  defp repair_image(%Image{} = image) do
    Image
    |> where(id: ^image.id)
    |> Repo.update_all(set: [thumbnails_generated: false, processed: false])

    enqueue_image_repair(image)
  end

  defp enqueue_image_repair(image) do
    Exq.enqueue(Exq, queue(image.image_mime_type), ThumbnailWorker, [image.id])

    image
  end

  defp queue("video/webm"), do: "videos"
  defp queue(_mime_type), do: "images"

  defp purge_files(image, hidden_key) do
    files =
      if is_nil(hidden_key) do
        Thumbnailer.thumbnail_urls(image, nil)
      else
        Thumbnailer.thumbnail_urls(image, hidden_key) ++
          Thumbnailer.thumbnail_urls(image, nil)
      end

    Exq.enqueue(Exq, "indexing", ImagePurgeWorker, [files])
  end

  ## Bulk operations

  defp reversion_pairs(changes, locked_image_ids, families, family_taggings) do
    changes
    |> Enum.group_by(& &1.image_id)
    |> Enum.filter(fn {image_id, _image_changes} -> image_id in locked_image_ids end)
    |> Enum.reduce({[], []}, fn {image_id, image_changes}, {added_pairs, removed_pairs} ->
      # Map each tag change to the relevant reversion operation.
      # Added tags should be removed; removed tags should be added.
      # Only one operation may occur per alias family.
      operations =
        image_changes
        |> Enum.flat_map(& &1.tag_changes)
        |> Enum.map(fn %{tag_id: tag_id, added: added} ->
          families
          |> Map.fetch!(tag_id)
          |> Map.put(:added, added)
        end)
        |> Enum.uniq_by(& &1.canonical_id)

      removed =
        operations
        |> Enum.filter(& &1.added)
        |> Enum.flat_map(fn op -> Enum.map(op.tag_ids, &%{image_id: image_id, tag_id: &1}) end)

      added =
        operations
        |> Enum.reject(& &1.added)
        |> Enum.reject(fn op ->
          # An alias source still present on the image already represents this
          # family, even when the migration has not inserted its canonical tag.
          Enum.any?(op.tag_ids, &MapSet.member?(family_taggings, {image_id, &1}))
        end)
        |> Enum.map(&%{image_id: image_id, tag_id: &1.canonical_id})

      {
        Enum.concat(added, added_pairs),
        Enum.concat(removed, removed_pairs)
      }
    end)
  end

  defp batch_tag_pairs(image_ids, added_tags, removed_tags) do
    # Compute cartesian products of image IDs and tag IDs.
    added =
      for image_id <- image_ids, tag <- added_tags do
        %{image_id: image_id, tag_id: tag.id}
      end

    removed =
      for image_id <- image_ids, tag <- removed_tags do
        %{image_id: image_id, tag_id: tag.id}
      end

    {added, removed}
  end

  defp put_perform_batch_update(%Multi{} = multi, attributes) do
    multi
    |> Multi.insert_all(
      :inserted_taggings,
      Tagging,
      fn %{locked_image_ids: image_ids, pairs: {added, _removed}} ->
        # Scope insertions to existing, requested images.
        Enum.filter(added, &(&1.image_id in image_ids))
      end,
      on_conflict: :nothing,
      returning: [:image_id, :tag_id]
    )
    |> Multi.delete_all(:deleted_taggings, fn
      %{locked_image_ids: image_ids, pairs: {_added, removed}} ->
        # Scope deletions to existing, requested images.
        removed
        |> Enum.filter(&(&1.image_id in image_ids))
        |> case do
          [] ->
            # The values API rejects an empty list.
            from t in Tagging,
              where: false,
              select: [t.image_id, t.tag_id]

          pairs ->
            from t in Tagging,
              join: pair in values(pairs, %{image_id: :integer, tag_id: :integer}),
              on: t.image_id == pair.image_id and t.tag_id == pair.tag_id,
              select: [t.image_id, t.tag_id]
        end
    end)
    |> TagChanges.put_batch_tag_changes(:inserted_taggings, :deleted_taggings, attributes)
    |> Tags.put_batch_image_count_changes(:inserted_taggings, :deleted_taggings, :visible_images)
    |> Multi.on_commit(fn %{locked_image_ids: image_ids} ->
      reindex_images(image_ids)
      Comments.reindex_comments_on_images(image_ids)
    end)
  end

  defp put_batch_revert_tag_changes(%Multi{} = multi, changes, attributes) do
    image_ids =
      changes
      |> Enum.map(& &1.image_id)
      |> Enum.uniq()

    tag_ids =
      changes
      |> Enum.flat_map(fn %{tag_changes: tag_changes} -> tag_changes end)
      |> Enum.map(& &1.tag_id)
      |> Enum.uniq()

    image_query =
      Image
      |> where([i], i.id in ^image_ids)
      |> order_by([i], asc: i.id)

    multi
    |> Multi.lock_all(:locked_image_ids, select(image_query, [i], i.id))
    |> Multi.all(:visible_images, where(image_query, [i], i.hidden_from_users == false))
    |> Tags.put_lock_tag_alias_families(tag_ids)
    |> Multi.all(:family_taggings, fn %{tag_alias_families: families} ->
      tag_ids =
        families
        |> Map.values()
        |> Enum.flat_map(& &1.tag_ids)
        |> Enum.uniq()

      from t in Tagging,
        where: t.image_id in ^image_ids and t.tag_id in ^tag_ids,
        select: {t.image_id, t.tag_id}
    end)
    |> Multi.run(:pairs, fn
      _repo,
      %{
        locked_image_ids: image_ids,
        tag_alias_families: families,
        family_taggings: family_taggings
      } ->
        {:ok, reversion_pairs(changes, image_ids, families, MapSet.new(family_taggings))}
    end)
    |> put_perform_batch_update(attributes)
  end

  defp put_batch_tag(%Multi{} = multi, actor, image_ids, added_names, removed_names, attributes) do
    image_query =
      Image
      |> where([i], i.id in ^image_ids)
      |> order_by(asc: :id)

    image_query =
      if authorize(actor, :show, %Image{hidden_from_users: true}) == :ok do
        image_query
      else
        where(image_query, hidden_from_users: false)
      end

    multi
    |> Multi.lock_all(:locked_image_ids, select(image_query, [i], i.id))
    |> Multi.all(:visible_images, where(image_query, hidden_from_users: false))
    |> Tags.put_canonicalize_tag_name_sets([
      {:removed_tags, removed_names, []},
      {:added_tags, added_names, expand_implications?: true}
    ])
    |> Multi.run(:changes, fn
      _repo, %{canonical_tags: %{added_tags: added_tags, removed_tags: removed_tags}} ->
        if Enum.empty?(added_tags) and Enum.empty?(removed_tags) do
          {:error, :no_change}
        else
          {:ok, nil}
        end
    end)
    |> Multi.run(:pairs, fn
      _repo,
      %{
        locked_image_ids: image_ids,
        canonical_tags: %{added_tags: added_tags, removed_tags: removed_tags}
      } ->
        {:ok, batch_tag_pairs(image_ids, added_tags, removed_tags)}
    end)
    |> put_perform_batch_update(attributes)
    |> Multi.on_commit(fn
      %{
        locked_image_ids: image_ids,
        canonical_tags: %{added_tags: added_tags, removed_tags: removed_tags}
      } ->
        broadcast_batch_update(image_ids, added_tags, removed_tags)
    end)
  end

  ## Voting and hiding

  defp deleted_vote_type(%{undownvote: {1, _}}), do: "downvote"
  defp deleted_vote_type(%{unupvote: {1, _}}), do: "upvote"
  defp deleted_vote_type(_changes), do: "vote"

  @doc group: "Browsing and discovery"
  @doc """
  Loads the most recent featured image visible to `actor`.

  Hidden images are always excluded. When `include_hidden?` is false, an
  authenticated actor's personally hidden images are also excluded. The next
  eligible historical feature is returned when the newest one is excluded.

  ## Examples

      iex> show_featured_image(actor, false)
      {:ok, %Image{}}

      iex> show_featured_image(actor, false)
      {:error, :not_found}

  """
  @spec show_featured_image(Actor.t(), boolean()) :: {:ok, Image.t()} | {:error, :not_found}
  def show_featured_image(%Actor{} = actor, include_hidden?) when is_boolean(include_hidden?) do
    with :ok <- authorize(actor, :index, Image) do
      Image
      |> maybe_exclude_viewer_hides(actor, include_hidden?)
      |> join(:inner, [i], f in ImageFeature, on: [image_id: i.id])
      |> where([i], i.hidden_from_users == false)
      |> order_by([_i, f], desc: f.created_at)
      |> limit(1)
      |> preload([:user, :intensity, :sources, tags: :aliases])
      |> Repo.one()
      |> case do
        nil ->
          {:error, :not_found}

        image ->
          {:ok, image}
      end
    end
  end

  @doc group: "Browsing and discovery"
  @doc """
  Loads the default image listing page for the viewer's search `scope`.

  Applies the front-page upload delay, the scope's filter and visibility
  switches, and the parameter-driven sort, then runs the search. Returns the
  record page with the standard listing preloads.

  ## Examples

      iex> list_images(actor, scope)
      %Scrivener.Page{}

  """
  @spec list_images(Actor.t(), Scope.t()) :: Scrivener.Page.t()
  def list_images(%Actor{} = actor, scope) do
    :ok = authorize(actor, :index, Image)
    {definition, _tags} = ImageSearch.default_query(actor, scope)

    ImageSearch.execute(definition)
  end

  @doc group: "Browsing and discovery"
  @doc """
  Runs the search the scope's "q" parameter describes for `actor`.

  Compiles "q" against the viewer's filter and visibility switches and executes
  it. The raw `Tag` records the query names come back alongside the page.

  Options:

    * `:preload` - the associations loaded onto the result records; defaults
      to the standard listing preloads.
    * `:hits` - whether each entry is paired with its search hit. A custom
      sort field (anything under "sf" other than `id`/`first_seen_at`) needs
      its sort cursor, so by default the page is loaded with hits exactly
      then; pass `false` to always load records alone.

  Returns `{:ok, %{images: page, tags: tags}}`, or the compiler's
  `{:error, msg}` for a malformed query.

  ## Examples

      iex> query_images(actor, scope)
      {:ok, %{images: %Scrivener.Page{}, tags: [%Tag{}]}}

      iex> query_images(actor, bad_query_scope)
      {:error, "There was an error parsing your query."}

  """
  @spec query_images(Actor.t(), Scope.t(), Keyword.t()) ::
          {:ok, %{images: Scrivener.Page.t(), tags: [Tag.t()]}} | {:error, String.t()}
  def query_images(%Actor{} = actor, scope, opts \\ []) do
    with :ok <- authorize(actor, :index, Image),
         sort = ImageSearch.scope_sort(scope),
         {:ok, {definition, tags}} <-
           ImageSearch.search_string(actor, scope, sort, scope.q) do
      preload = Keyword.get(opts, :preload, [:sources, tags: :aliases])
      hits = Keyword.get(opts, :hits, custom_ordering?(scope))

      images = ImageSearch.execute(definition, preload: preload, hits: hits)

      {:ok, %{images: images, tags: tags}}
    end
  end

  @doc group: "Browsing and discovery"
  @doc """
  Loads an image representation for the JSON API or oEmbed on behalf of
  `actor`.

  The image carries the associations required by the API renderer.
  Missing IDs are actor-independent.

  ## Examples

      iex> show_api_image(actor, "1")
      {:ok, %Image{}}

      iex> show_api_image(actor, "missing")
      {:error, :not_found}

  """
  @spec show_api_image(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()} | {:error, :not_found}
  def show_api_image(%Actor{} = _actor, image_id) do
    Loader.fetch(Image, image_id, [:user, :intensity, :sources, tags: :aliases])
  end

  @doc group: "Browsing and discovery"
  @doc """
  Runs the "my:watched" search for the viewer scope, with the watched-feed
  preloads, and returns the record page.

  ## Examples

      iex> list_watched_images(actor, scope)
      {:ok, %Scrivener.Page{}}

  """
  @spec list_watched_images(Actor.t(), Scope.t()) ::
          {:ok, Scrivener.Page.t()} | {:error, :unauthorized | String.t()}
  def list_watched_images(%Actor{} = actor, scope) do
    with :ok <- authorize(actor, :index_watched, Image),
         sort = ImageSearch.scope_sort(scope),
         {:ok, {definition, _tags}} <- ImageSearch.search_string(actor, scope, sort, "my:watched") do
      {:ok, ImageSearch.execute(definition)}
    end
  end

  @doc group: "Browsing and discovery"
  @doc """
  Loads the image named by `id` for showing, on behalf of `actor`.

  The image carries its preloads plus virtual fields for these counts: distinct
  tag changes, tags touched by those changes, and source changes. An image merged
  into a duplicate is redirected for non-staff viewers, returning
  `{:duplicate_of, target_image_id}` so the caller can redirect to the target. A
  malformed or unknown id is `{:error, :not_found}`.

  ## Examples

      iex> show_image(actor, "1")
      {:ok, %Image{tag_change_count: 2, tag_change_tag_count: 5, source_change_count: 1}}

      iex> show_image(actor, "2")
      {:duplicate_of, 42}

      iex> show_image(actor, "bad")
      {:error, :not_found}

  """
  @spec show_image(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()}
          | {:duplicate_of, IntegerId.integer_id()}
          | {:error, :not_found}
  def show_image(%Actor{} = actor, id) do
    with {:ok, image} <-
           Image
           |> from(as: :image)
           |> join(:inner_lateral, [], subquery(TagChanges.count_query()), on: true)
           |> join(:inner_lateral, [], subquery(SourceChanges.count_query()), on: true)
           |> preload([:deleter, :locked_tags, :sources, user: [awards: :badge], tags: :aliases])
           |> select([image, tag_changes, source_changes], %{
             image
             | tag_change_count: tag_changes.change_count,
               tag_change_tag_count: tag_changes.tag_count,
               source_change_count: source_changes.count
           })
           |> Loader.fetch(id) do
      cond do
        authorize(actor, :show, image) == :ok ->
          {:ok, image}

        not is_nil(image.duplicate_id) ->
          {:duplicate_of, image.duplicate_id}

        true ->
          {:ok, image}
      end
    end
  end

  @doc group: "Browsing and discovery"
  @doc """
  Assembles the `ImagePage` for `actor`: the visible page of comments,
  the viewer's subscription state, their galleries paired with membership of
  this image, their interactions, and changesets for each action available on
  the page.

  Clears the viewer's notification for the image as a side effect, so the
  caller must read any notification counts afterwards. `comment_pagination`
  is the `page`/`page_size` keyword list. Viewers who read oldest-first and
  prefer jumping to the newest comments land on the last page unless they
  asked for a specific one. Interaction controls and comment changesets are
  omitted when the actor is banned, the image is hidden or forced-filtered, or
  the corresponding action is forbidden. A missing fingerprint does not omit
  them; only the submitted write requires one. Moderation
  changesets follow their own action authorization so authorized staff can
  still render management controls for hidden images.

  ## Examples

      iex> show_image_page(actor, image, page: 1, page_size: 25)
      %ImagePage{}

  """
  @spec show_image_page(Actor.t(), Image.t(), Repo.pagination_params()) :: ImagePage.t()
  def show_image_page(%Actor{user: user} = actor, %Image{} = image, comment_pagination) do
    clear_image_notification(image, user)

    comment_pagination = maybe_jump_to_last_page(actor, image, comment_pagination)
    {:ok, gallery_choices} = Galleries.gallery_choices_for_image(actor, image)

    can_interact = image_interaction_allowed?(actor, image)

    %ImagePage{
      image: image,
      comments: Comments.list_image_comments(actor, image, comment_pagination),
      watching: subscribed?(image, user),
      can_interact: can_interact,
      user_galleries: gallery_choices,
      interactions: Interactions.user_interactions(actor, [image]),
      comment_changeset: comment_changeset_for(actor, image),
      description_changeset: image_changeset_for(actor, image, :edit_description),
      tag_changeset: image_changeset_for(actor, image, :edit_metadata),
      source_changeset: image_changeset_for(actor, image, :edit_metadata),
      file_changeset: image_changeset_for(actor, image, :replace_file),
      hide_changeset: image_changeset_for(actor, image, :hide),
      feature_changeset: image_changeset_for(actor, image, :feature),
      repair_changeset: image_changeset_for(actor, image, :repair),
      hash_changeset: image_changeset_for(actor, image, :remove_hash),
      uploader_changeset: uploader_changeset_for(actor, image)
    }
  end

  @doc group: "Browsing and discovery"
  @doc """
  Finds the image adjacent to the one `image_id` names in the listing the
  scope's parameters describe, for prev/next navigation, on behalf of
  `actor`.

  The image locator is parsed and loaded before `:show` authorization, so both
  malformed and unknown ids are `{:error, :not_found}`. The scope's "q"
  parameter (blank means everything) is compiled for the viewer; malformed
  queries return the parser error instead of navigating an unfiltered result.

  Returns `{:ok, {image, {adjacent, hit}}}`, where the hit carries the sort cursor
  for the caller to reuse, or `{:ok, {image, nil}}` at the end of the sequence.

  ## Examples

      iex> list_image_navigation(actor, scope, "42")
      {:ok, {%Image{}, {%Image{}, %{"sort" => [...]}}}}

  """
  @spec list_image_navigation(Actor.t(), Scope.t(), IntegerId.integer_id()) ::
          {:ok, {Image.t(), {Image.t(), map()} | nil}}
          | {:error, :unauthorized | :not_found | String.t()}
  def list_image_navigation(%Actor{user: user} = actor, scope, image_id) do
    with {:ok, image} <- load_image_member(actor, :show, image_id),
         {:ok, query} <- ImageQuery.compile(scope.q || "*", user: user) do
      {:ok, {image, ImageSearch.find_consecutive(actor, scope, image, query)}}
    end
  end

  @doc group: "Browsing and discovery"
  @doc """
  Returns the 1-based page number on which the image `image_id`
  names appears when all images are listed by the default sort, on behalf of
  `actor`.

  Loading and authorization follow `find_consecutive_image/3`.

  ## Examples

      iex> list_image_index_page(actor, scope, "42")
      {:ok, 3}

  """
  @spec list_image_index_page(Actor.t(), Scope.t(), IntegerId.integer_id()) ::
          {:ok, pos_integer()} | {:error, :unauthorized | :not_found}
  def list_image_index_page(%Actor{} = actor, scope, image_id) do
    with {:ok, image} <- load_image_member(actor, :show, image_id) do
      pagination = %{scope.pagination | page_number: 1}

      {definition, _tags} =
        ImageSearch.query(
          actor,
          scope,
          ImageSearch.default_sort(),
          %{range: %{id: %{gt: image.id}}},
          pagination: pagination
        )

      images = ImageSearch.execute(definition, preload: [])

      {:ok, div(images.total_entries, pagination.page_size) + 1}
    end
  end

  @doc group: "Browsing and discovery"
  @doc """
  Loads images related to the one `image_id` names. Related images share its
  lowest-population tags, weighted towards its most distinctive ones and the
  favers it has in common.

  Loading and authorization follow `find_consecutive_image/3`; the image
  carries the faves, sources, and tags the scoring reads.

  Returns `{:ok, {image, images}}` with the related images scored best-first.

  ## Examples

      iex> list_related_images(actor, scope, "42")
      {:ok, {%Image{}, %Scrivener.Page{}}}

  """
  @spec list_related_images(Actor.t(), Scope.t(), IntegerId.integer_id()) ::
          {:ok, {Image.t(), Scrivener.Page.t()}} | {:error, :unauthorized | :not_found}
  def list_related_images(%Actor{} = actor, scope, image_id) do
    with {:ok, image} <-
           load_image_member(actor, :show, image_id, [:faves, :sources, tags: :aliases]) do
      tags_to_match =
        image.tags
        |> Enum.reject(&(&1.category == "rating"))
        |> Enum.sort_by(& &1.images_count)
        |> Enum.take(10)
        |> Enum.map(& &1.id)

      low_count_tags =
        tags_to_match
        |> Enum.take(5)
        |> Enum.map(&%{term: %{tag_ids: &1}})

      high_count_tags =
        tags_to_match
        |> Enum.take(-5)
        |> Enum.map(&%{term: %{tag_ids: &1}})

      favs_to_match =
        image.faves
        |> Enum.take(11)
        |> Enum.map(&%{term: %{favourited_by_user_ids: &1.user_id}})

      query = %{
        bool: %{
          must: [
            %{bool: %{should: low_count_tags, boost: 2}},
            %{bool: %{should: high_count_tags, boost: 3, minimum_should_match: "5%"}},
            %{bool: %{should: favs_to_match, boost: 0.2, minimum_should_match: "5%"}}
          ],
          must_not: %{term: %{id: image.id}}
        }
      }

      {definition, _tags} =
        ImageSearch.query(
          actor,
          scope,
          ImageSearch.relevance_sort(),
          query,
          pagination: %{scope.pagination | page_number: 1}
        )

      {:ok, {image, ImageSearch.execute(definition)}}
    end
  end

  @doc group: "Browsing and discovery"
  @doc """
  Picks a random image id from the listing the scope's "q" parameter
  describes (everything when absent), respecting the scope's filter and
  visibility switches.

  Returns `{:ok, id}` or `{:ok, nil}` when nothing matches. A malformed query
  returns `{:error, parser_message}`.

  ## Examples

      iex> list_random_images(actor, scope)
      {:ok, 42}

  """
  @spec list_random_images(Actor.t(), Scope.t()) ::
          {:ok, integer() | nil} | {:error, :unauthorized | String.t()}
  def list_random_images(%Actor{} = actor, scope) do
    with :ok <- authorize(actor, :index, Image),
         {:ok, {definition, _tags}} <-
           ImageSearch.search_string(
             actor,
             scope,
             ImageSearch.random_sort(),
             scope.q || "*",
             pagination: %{page_size: 1}
           ) do
      definition
      |> ImageSearch.execute(preload: [])
      |> Enum.to_list()
      |> case do
        [image] ->
          {:ok, image.id}

        [] ->
          {:ok, nil}
      end
    end
  end

  @doc group: "Browsing and discovery"
  @doc """
  Loads the image named by `image_id`, applying `preloads`, and authorizes
  `actor` for `:show` on it.

  Returns `{:ok, image}`, `{:error, :unauthorized}`, or `{:error, :not_found}`.

  ## Examples

      iex> load_visible_image(actor, "1")
      {:ok, %Image{}}

      iex> load_visible_image(actor, "999999999")
      {:error, :not_found}

  """
  @spec load_visible_image(Actor.t(), IntegerId.integer_id(), list()) ::
          {:ok, Image.t()} | {:error, :unauthorized | :not_found}
  def load_visible_image(actor, image_id, preloads \\ []) do
    load_image_member(actor, :show, image_id, preloads)
  end

  @doc group: "Browsing and discovery"
  @doc """
  Loads an image as a report target on behalf of `actor`.

  The image is authorized for `:show` and carries the sources and tag aliases
  rendered by the shared report form. Missing IDs are always not-found.

  ## Examples

      iex> load_report_target(actor, "1")
      {:ok, %Image{}}
  """
  @spec load_report_target(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()} | {:error, :unauthorized | :not_found}
  def load_report_target(%Actor{} = actor, image_id) do
    load_image_member(actor, :show, image_id, [:sources, tags: :aliases])
  end

  @doc group: "Browsing and discovery"
  @doc """
  Loads images by ID with the associations required by rich text references.

  Unknown IDs are omitted. Results are not guaranteed to follow the input
  order; callers which need keyed access should index them by ID.

  ## Examples

      iex> list_images_by_ids([42, 999_999_999])
      [%Image{id: 42}]

  """
  @spec list_images_by_ids([integer()]) :: [Image.t()]
  def list_images_by_ids(ids) when is_list(ids) do
    Image
    |> where([image], image.id in ^ids)
    |> preload([:sources, tags: :aliases])
    |> Repo.all()
  end

  @doc group: "Cross-context transaction helpers"
  @doc """
  Adds a loaded-image merge to `multi` without transacting it.

  The caller owns authorization and must lock the two images before merging
  this service when their current state controls the operation. PostgreSQL
  mutations join the caller's transaction; thumbnail work, indexing, and the
  firehose broadcast run only after that transaction commits.

  ## Examples

      iex> put_merge_image(multi, source_image, target_image, moderator)
      %Philomena.Multi{}

  """
  @spec put_merge_image(Multi.t(), Image.t(), Image.t(), User.t()) :: Multi.t()
  def put_merge_image(
        %Multi{} = multi,
        %Image{} = image,
        %Image{} = duplicate_of_image,
        %User{} = user
      ) do
    image =
      Repo.preload(image, [:user, :intensity, :sources, tags: :aliases])

    duplicate_of_image =
      Repo.preload(duplicate_of_image, [:user, :intensity, :sources, tags: :aliases])

    subscriptions =
      Subscription
      |> where(image_id: ^image.id)
      |> select([s], %{image_id: type(^duplicate_of_image.id, :integer), user_id: s.user_id})

    source_changeset =
      Image.merge_source_changeset(image, duplicate_of_image)

    multi
    |> put_hide_image(source_changeset, image, user)
    |> Galleries.put_migrate_image_interactions(image, duplicate_of_image)
    |> Tags.put_copy_tags(image, duplicate_of_image)
    |> Multi.update(:target_image, fn _changes ->
      sources =
        (image.sources ++ duplicate_of_image.sources)
        |> Enum.map(fn s -> %Source{image_id: duplicate_of_image.id, source: s.source} end)
        |> Enum.uniq()
        |> Enum.take(15)

      duplicate_of_image
      |> Image.first_seen_at_changeset([image, duplicate_of_image])
      |> Image.sources_changeset(sources)
    end)
    |> Comments.put_migrate_image_comments(image, duplicate_of_image)
    |> Multi.insert_all(:subscriptions, Subscription, subscriptions, on_conflict: :nothing)
    |> Notifications.put_migrate_image_notifications(image, duplicate_of_image)
    |> Interactions.migrate_loaded_images(image, duplicate_of_image)
    |> Multi.run(:notification, fn _repo, _changes ->
      Notifications.broadcast_image_merge(duplicate_of_image, image)
    end)
    |> Multi.on_commit(fn result ->
      reindex_image(duplicate_of_image)
      Comments.reindex_comments_on_image(duplicate_of_image)
      broadcast_image_merge(result.image, duplicate_of_image)
    end)
  end

  @doc group: "Cross-context transaction helpers"
  @doc """
  Adds the inverse of a source change to `multi` without recording a new
  source-change row.

  The image is locked and reindexed after the transaction commits. The
  corresponding source-change row can be deleted by composing this operation
  with `Philomena.SourceChanges.put_erase_source_change/2`.

  ## Examples

      iex> put_revert_source_change(multi, source_change)
      %Philomena.Multi{}

  """
  @spec put_revert_source_change(Multi.t(), SourceChange.t()) :: Multi.t()
  def put_revert_source_change(%Multi{} = multi, %SourceChange{} = source_change) do
    {added_sources, removed_sources} =
      if source_change.added do
        {[], [source_change.source_url]}
      else
        {[source_change.source_url], []}
      end

    image_query =
      Image
      |> where(id: ^source_change.image_id)
      |> preload(:sources)

    multi
    |> Multi.lock_one(:locked_image, image_query)
    |> Multi.update(:image, fn %{locked_image: image} ->
      Image.source_changeset(image, added_sources, removed_sources)
    end)
    |> put_reindex_image(:image)
  end

  @doc group: "Cross-context transaction helpers"
  @doc """
  Adds a denormalized image counter adjustment to `multi`.

  Image interactions and other contexts use this function instead of updating
  the `images` table themselves. `amount_or_callback` reads the exact delta
  from prior Multi changes when it is known only after a delete.
  """
  @spec put_image_counter_delta(
          Multi.t(),
          Multi.name(),
          integer(),
          atom(),
          integer() | (Multi.changes() -> integer())
        ) :: Multi.t()
  def put_image_counter_delta(
        %Multi{} = multi,
        step,
        image_id,
        field,
        amount_or_callback
      )
      when is_atom(field) and is_integer(image_id) do
    put_image_counter_deltas(multi, step, image_id, fn changes ->
      cond do
        is_function(amount_or_callback, 1) -> %{field => amount_or_callback.(changes)}
        is_integer(amount_or_callback) -> %{field => amount_or_callback}
      end
    end)
  end

  @doc group: "Cross-context transaction helpers"
  @doc """
  Adds multiple denormalized image counter adjustments to `multi`.

  The owner attaches one image reindex after commit for the complete update.
  """
  @spec put_image_counter_deltas(
          Multi.t(),
          Multi.name(),
          integer(),
          (Multi.changes() -> %{atom() => integer()})
        ) :: Multi.t()
  def put_image_counter_deltas(%Multi{} = multi, step, image_id, increments_callback) do
    Multi.run(multi, step, fn repo, changes ->
      increments = increments_callback.(changes)

      {count, _} = repo.update_all(where(Image, id: ^image_id), inc: Map.to_list(increments))

      {:ok, count}
    end)
    |> Multi.on_commit(fn _changes -> reindex_images([image_id]) end)
  end

  @doc group: "Cross-context transaction helpers"
  @doc """
  Adds deletion of image taggings represented by `query` to `multi`.

  Tag maintenance composes this function when removing or migrating a tag.
  """
  @spec put_delete_taggings(Multi.t(), Multi.name(), Ecto.Query.t()) :: Multi.t()
  def put_delete_taggings(%Multi{} = multi, step, %Ecto.Query{} = query) do
    image_ids_step = {:tagging_image_ids, step}
    image_ids_query = query |> exclude(:select) |> select([tagging], tagging.image_id)

    multi
    |> Multi.all(image_ids_step, image_ids_query)
    |> Multi.delete_all(step, query)
    |> Multi.on_commit(fn %{^image_ids_step => image_ids} -> reindex_images(image_ids) end)
  end

  @doc group: "Cross-context transaction helpers"
  @doc """
  Adds insertion of image taggings represented by `entries` to `multi`.

  Tag maintenance composes this function when migrating a tag.
  """
  @spec put_insert_taggings(Multi.t(), Multi.name(), [map()] | Ecto.Query.t()) :: Multi.t()
  def put_insert_taggings(%Multi{} = multi, step, entries) when is_list(entries) do
    multi
    |> Multi.insert_all(step, Tagging, entries,
      on_conflict: :nothing,
      returning: [:image_id, :tag_id]
    )
    |> Multi.on_commit(fn %{^step => {_count, taggings}} ->
      taggings
      |> Enum.map(& &1.image_id)
      |> reindex_images()
    end)
  end

  def put_insert_taggings(%Multi{} = multi, step, %Ecto.Query{} = query) do
    image_ids_step = {:tagging_image_ids, step}
    image_ids_query = query |> exclude(:select) |> select([tagging], tagging.image_id)

    multi
    |> Multi.all(image_ids_step, image_ids_query)
    |> Multi.insert_all(step, Tagging, query,
      on_conflict: :nothing,
      returning: [:image_id, :tag_id]
    )
    |> Multi.on_commit(fn %{^image_ids_step => image_ids} -> reindex_images(image_ids) end)
  end

  @doc group: "Cross-context transaction helpers"
  @doc """
  Copies an image's taggings to another image inside `multi`.

  The inserted tag IDs are returned in `:copied_tag_ids` for Tags' counter
  maintenance.
  """
  @spec put_copy_taggings(Multi.t(), Image.t(), Image.t()) :: Multi.t()
  def put_copy_taggings(%Multi{} = multi, %Image{} = source, %Image{} = target) do
    source_taggings_query =
      Tagging
      |> where(image_id: ^source.id)
      |> select([tagging], %{
        image_id: type(^target.id, :integer),
        tag_id: tagging.tag_id
      })

    multi
    |> Multi.all(:source_taggings, source_taggings_query)
    |> Multi.insert_all(
      :target_taggings,
      Tagging,
      fn %{source_taggings: source_taggings} -> source_taggings end,
      on_conflict: :nothing,
      returning: [:tag_id]
    )
    |> Multi.run(:copied_tag_ids, fn _repo, %{target_taggings: {_count, taggings}} ->
      {:ok, Enum.map(taggings, & &1.tag_id)}
    end)
    |> Multi.on_commit(fn _changes -> reindex_images([target.id]) end)
  end

  @doc group: "Forms and uploads"
  @doc """
  Returns an `%Ecto.Changeset{}` for tracking image changes.

  ## Examples

      iex> change_image(image)
      %Ecto.Changeset{source: %Image{}}

  """
  @spec change_image(Image.t()) :: Ecto.Changeset.t()
  def change_image(%Image{} = image) do
    Image.changeset(image, %{})
  end

  @doc group: "Forms and uploads"
  @doc """
  Gets the tag list for a single image.
  """
  @spec tag_list(Image.t()) :: String.t()
  def tag_list(%Image{tags: tags}) do
    tags
    |> Tag.display_order()
    |> Enum.map_join(", ", & &1.name)
  end

  @doc group: "Forms and uploads"
  @doc """
  Builds the changeset for a new image upload, on behalf of `actor`.

  A banned actor is rejected with `{:error, :ban}`; everyone else gets the
  changeset.

  ## Examples

      iex> new_image(actor)
      {:ok, %Ecto.Changeset{}}

      iex> new_image(banned_actor)
      {:error, :ban}

  """
  @spec new_image(Actor.t()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :unauthorized}
  def new_image(%Actor{} = actor) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :new, Image) do
      {:ok, change_image(%Image{sources: [%Source{}]})}
    end
  end

  @image_create_window 5

  @doc group: "Forms and uploads"
  @doc """
  Uploads a new image on behalf of `actor`, who must pass the write-access
  check: banned actors get `{:error, :ban}` and actors without a fingerprint
  `{:error, :unauthorized}`. A non-exempt actor who has uploaded within the last
  5 seconds gets `{:error, :rate_limited}`.

  Upon success, the image row has been created and processing continues in the
  background. Approved uploads increment the uploader's image count and may
  create a verification report in the same transaction.

  ## Examples

      iex> create_image(actor, %{"tag_input" => "safe"}, upload)
      {:ok, %Image{}}

      iex> create_image(banned_actor, params, upload)
      {:error, :ban}

  """
  @spec create_image(Actor.t(), map() | nil, PhilomenaMedia.Upload.t() | nil) ::
          {:ok, Image.t()}
          | {:error, :ban | :unauthorized | :rate_limited | Ecto.Changeset.t()}
  def create_image(%Actor{user: user} = actor, params, upload) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, Image),
         {:ok, tag_input_form} <-
           %TagInputForm{}
           |> TagInputForm.changeset(params)
           |> TagInputForm.apply(%Image{}),
         {:ok, source_input_form} <-
           %SourceInputForm{}
           |> SourceInputForm.changeset(params)
           |> SourceInputForm.apply(%Image{}) do
      %{added: added_tag_names} = TagDiffer.diff_inputs(nil, tag_input_form.tag_input)
      %{added: added_sources} = SourceDiffer.diff_inputs(nil, source_input_form.sources)

      image_changeset =
        %Image{}
        |> Image.creation_changeset(params, actor)
        |> Uploader.analyze_upload(upload)
        |> maybe_approve_image(user)

      Multi.new()
      |> Multi.reserve_action(
        fn -> RateLimiter.record_action(actor, :image_create, @image_create_window) end,
        fn -> RateLimiter.rollback_action(actor, :image_create) end
      )
      |> Tags.put_canonicalize_tag_name_sets([
        {:added_tags, added_tag_names, allow_insert_new?: true, expand_implications?: true}
      ])
      |> DnpEntries.put_dnp_tags(:dnp_tags, :canonical_tags)
      |> Multi.insert(:image, fn
        %{
          canonical_tags: %{added_tags: added_tags},
          dnp_tags: tags_with_dnp
        } ->
          image_changeset
          |> Image.source_changeset(added_sources, [])
          |> Image.tag_changeset(added_tags, [])
          |> Image.dnp_changeset(user, tags_with_dnp)
      end)
      |> Tags.put_image_count_delta(
        :added_tag_count,
        fn %{image: image} -> Enum.map(image.added_tags, & &1.id) end,
        1
      )
      |> maybe_subscribe_on(:image, user, :watch_on_upload)
      |> put_approval_steps()
      |> put_reindex_image(:image)
      |> Multi.transact_with_automatic_retry()
      |> case do
        {:ok, %{image: %Image{} = image}} ->
          :ok = async_upload(image, upload)

          image = Repo.preload(image, tags: :aliases)

          broadcast_image_create(image)

          {:ok, image}

        {:error, :action_reservation, :rate_limited, _changes} ->
          {:error, :rate_limited}

        {:error, :image, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          error
      end
    end
  end

  @doc group: "Moderation and lifecycle"
  @doc """
  Returns the paginated approval queue for `actor`: unapproved images, oldest
  first, with the listing preloads.

  Returns `{:ok, images}` as a `m:Scrivener.Page` or `{:error, :unauthorized}`.

  ## Examples

      iex> list_approval_queue(moderator, pagination)
      {:ok, %Scrivener.Page{}}

      iex> list_approval_queue(user, pagination)
      {:error, :unauthorized}

  """
  @spec list_approval_queue(Actor.t(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t()} | {:error, :unauthorized}
  def list_approval_queue(%Actor{} = actor, pagination) do
    with :ok <- authorize(actor, :approve, %Image{}) do
      images =
        Image
        |> where(approved: false)
        |> order_by(asc: :id)
        |> preload([:user, :sources, tags: [:aliases, :aliased_tag]])
        |> Repo.paginate(pagination)

      {:ok, images}
    end
  end

  @doc group: "Moderation and lifecycle"
  @doc """
  Approves the image named by `image_id` for public viewing, on behalf of
  `actor`.

  An image that is already approved returns an error changeset and is left
  untouched. On success the image is made visible, statistics are updated, the
  image and its comments are reindexed, and a moderation log is written
  attributing the approval to `actor`. Approval at the uploader's fifth
  approved image also creates a verification report in the same transaction.

  Returns `{:ok, image}` with the approved image.

  ## Examples

      iex> create_image_approve(moderator, "42")
      {:ok, %Image{}}

      iex> create_image_approve(user, "42")
      {:error, :unauthorized}

  """
  @spec create_image_approve(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found}
  def create_image_approve(%Actor{} = actor, image_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :approve, image_id) do
      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> Multi.update(:image, fn %{locked_image: image} -> Image.approve_changeset(image) end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{locked_image: image} ->
        {"Image.Approve:create", Paths.image_path(image), "Approved image #{image.id}"}
      end)
      |> put_approval_steps()
      |> put_reindex_image(:image)
      |> Multi.on_commit(fn %{image: image} -> Comments.reindex_comments_on_image(image) end)
      |> Multi.transact()
      |> case do
        {:ok, %{image: %Image{} = image}} ->
          {:ok, image}

        {:error, :image, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          error
      end
    end
  end

  @doc group: "Moderation and lifecycle"
  @doc """
  Counts the number of images pending approval that a user can moderate.

  ## Examples

      iex> count_pending_approvals(admin)
      42

      iex> count_pending_approvals(user)
      nil

  """
  @spec count_pending_approvals(Actor.t()) :: non_neg_integer() | nil
  def count_pending_approvals(%Actor{} = actor) do
    if authorize(actor, :approve, %Image{}) == :ok do
      Image
      |> where(approved: false)
      |> Repo.aggregate(:count)
    else
      nil
    end
  end

  @doc group: "Moderation and lifecycle"
  @doc """
  Marks the image named by `image_id` as the current featured image, on behalf
  of `actor`.

  The image is loaded by id and authorized for `:feature`. On success the feature is
  recorded and a moderation log is written attributing it to `actor`.

  Returns `{:ok, feature}` with the created feature, or
  `{:error, %Ecto.Changeset{}}` when the image is deleted.

  ## Examples

      iex> create_image_feature(moderator, "42")
      {:ok, %ImageFeature{}}

      iex> create_image_feature(user, "42")
      {:error, :unauthorized}

  """
  @spec create_image_feature(Actor.t(), IntegerId.integer_id()) ::
          {:ok, ImageFeature.t()}
          | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def create_image_feature(%Actor{} = actor, image_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :feature, image_id) do
      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> Multi.insert(:feature, fn %{locked_image: image} ->
        %ImageFeature{user_id: actor.user.id, image_id: image.id}
        |> ImageFeature.feature_changeset(image)
      end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{locked_image: image} ->
        {"Image.Feature:create", Paths.image_path(image), "Featured image #{image.id}"}
      end)
      |> Multi.transact()
      |> case do
        {:ok, %{feature: %ImageFeature{} = feature}} ->
          {:ok, feature}

        {:error, :feature, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Moderation and lifecycle"
  @doc """
  Hard-deletes the contents of the image named by `image_id`, on behalf of
  `actor`, purging its stored file and thumbnails.

  The image is loaded by id and authorized for `:destroy`. Only an already-deleted
  image (hidden from users) may be destroyed; a still-visible image is
  `{:error, :not_deleted}`, left untouched. On success the file and thumbnails are
  purged and a moderation log is written attributing the destruction to `actor`.

  Returns `{:ok, image}` with the destroyed image, or
  `{:error, %Ecto.Changeset{}}` if the destruction is rejected.

  ## Examples

      iex> create_image_destroy(admin, "42")
      {:ok, %Image{}}

      iex> create_image_destroy(moderator, "42")
      {:error, :unauthorized}

  """
  @spec create_image_destroy(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()}
          | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def create_image_destroy(%Actor{} = actor, image_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :destroy, image_id) do
      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> Multi.update(:image, fn %{locked_image: image} ->
        Image.remove_image_changeset(image)
      end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{image: image} ->
        {"Image.Destroy:create", Paths.image_path(image), "Hard-deleted image #{image.id}"}
      end)
      |> put_reindex_image(:image)
      |> Multi.transact()
      |> case do
        {:ok, %{image: %Image{} = image}} ->
          purge_files(image, image.hidden_image_key)
          Thumbnailer.destroy_thumbnails(image)

          {:ok, image}

        {:error, :image, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Moderation and lifecycle"
  @doc """
  Locks (`locked?` true) or unlocks (`locked?` false) comments on the image
  named by `image_id`, on behalf of `actor`.

  The image is loaded by id and authorized for `:lock_comments`. On success commenting
  is toggled, the image is reindexed, and a moderation log is written attributing
  the change to `actor`.

  Returns `{:ok, image}` with the updated image.

  ## Examples

      iex> update_image_comment_lock(moderator, "42", true)
      {:ok, %Image{}}

      iex> update_image_comment_lock(user, "42", true)
      {:error, :unauthorized}

  """
  @spec update_image_comment_lock(Actor.t(), IntegerId.integer_id(), boolean()) ::
          {:ok, Image.t()} | {:error, :ban | :unauthorized | :not_found}
  def update_image_comment_lock(%Actor{} = actor, image_id, locked?) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :lock_comments, image_id) do
      {log_type, log_body} =
        if locked? do
          {"Image.CommentLock:create", "Locked comments on image #{image.id}"}
        else
          {"Image.CommentLock:delete", "Unlocked comments on image #{image.id}"}
        end

      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> Multi.update(:image, fn %{locked_image: image} ->
        Image.lock_comments_changeset(image, locked?)
      end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{image: image} ->
        {log_type, Paths.image_path(image), log_body}
      end)
      |> put_reindex_image(:image)
      |> Multi.transact()
      |> case do
        {:ok, %{image: %Image{} = image}} ->
          {:ok, image}
      end
    end
  end

  @doc group: "Moderation and lifecycle"
  @doc """
  Locks (`locked?` true) or unlocks (`locked?` false) description editing on the
  image named by `image_id`, on behalf of `actor`.

  The image is loaded by id and authorized for `:lock_description`. On success description
  editing is toggled, the image is reindexed, and a moderation log is written
  attributing the change to `actor`.

  Returns `{:ok, image}` with the updated image.

  ## Examples

      iex> update_image_description_lock(moderator, "42", true)
      {:ok, %Image{}}

      iex> update_image_description_lock(user, "42", true)
      {:error, :unauthorized}

  """
  @spec update_image_description_lock(Actor.t(), IntegerId.integer_id(), boolean()) ::
          {:ok, Image.t()} | {:error, :ban | :unauthorized | :not_found}
  def update_image_description_lock(%Actor{} = actor, image_id, locked?) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :lock_description, image_id) do
      {log_type, log_body} =
        if locked? do
          {"Image.DescriptionLock:create", "Locked description editing on image #{image.id}"}
        else
          {"Image.DescriptionLock:delete", "Unlocked description editing on image #{image.id}"}
        end

      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> Multi.update(:image, fn %{locked_image: image} ->
        Image.lock_description_changeset(image, locked?)
      end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{image: image} ->
        {log_type, Paths.image_path(image), log_body}
      end)
      |> put_reindex_image(:image)
      |> Multi.transact()
      |> case do
        {:ok, %{image: %Image{} = image}} ->
          {:ok, image}
      end
    end
  end

  @doc group: "Moderation and lifecycle"
  @doc """
  Locks (`locked?` true) or unlocks (`locked?` false) tag editing on the image
  named by `image_id`, on behalf of `actor`.

  The image is loaded by id and authorized for `:lock_tags`. On success tag editing
  is toggled, the image is reindexed, and a moderation log is written attributing
  the change to `actor`.

  Returns `{:ok, image}` with the updated image.

  ## Examples

      iex> update_image_tag_lock(moderator, "42", true)
      {:ok, %Image{}}

      iex> update_image_tag_lock(user, "42", true)
      {:error, :unauthorized}

  """
  @spec update_image_tag_lock(Actor.t(), IntegerId.integer_id(), boolean()) ::
          {:ok, Image.t()} | {:error, :ban | :unauthorized | :not_found}
  def update_image_tag_lock(%Actor{} = actor, image_id, locked?) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :lock_tags, image_id) do
      {log_type, log_body} =
        if locked? do
          {"Image.TagLock:create", "Locked tags on image #{image.id}"}
        else
          {"Image.TagLock:delete", "Unlocked tags on image #{image.id}"}
        end

      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> Multi.update(:image, fn %{locked_image: image} ->
        Image.lock_tags_changeset(image, locked?)
      end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{image: image} ->
        {log_type, Paths.image_path(image), log_body}
      end)
      |> put_reindex_image(:image)
      |> Multi.transact()
      |> case do
        {:ok, %{image: %Image{} = image}} ->
          {:ok, image}
      end
    end
  end

  @doc group: "Moderation and lifecycle"
  @doc """
  Loads the image named by `image_id` for moderation, on behalf of `actor`.

  The image is loaded by id and authorized for `:hide`. Callers use this loader
  to render moderation forms, so a banned actor gets `{:error, :ban}`, while a
  missing fingerprint is left to the submitted write.

  Returns `{:ok, image}` with the loaded image, carrying the associations
  named by `opts[:preload]` (none by default).

  ## Examples

      iex> load_hidable_image(moderator, "42")
      {:ok, %Image{}}

      iex> load_hidable_image(user, "42")
      {:error, :unauthorized}

  """
  @spec load_hidable_image(Actor.t(), IntegerId.integer_id(), Keyword.t()) ::
          {:ok, Image.t()} | {:error, :ban | :unauthorized | :not_found}
  def load_hidable_image(%Actor{} = actor, image_id, opts \\ []) do
    with :ok <- verify_not_banned(actor) do
      load_image_member(actor, :hide, image_id, Keyword.get(opts, :preload, []))
    end
  end

  @doc group: "Moderation and lifecycle"
  @doc """
  Repairs the image named by `image_id`, on behalf of `actor`, by regenerating
  its thumbnails and purging its cached files.

  The image is loaded by id and authorized for `:repair`. On success the thumbnail
  regeneration job is enqueued, the image's CDN files are purged, and a moderation
  log is written attributing the repair to `actor`.

  Returns `{:ok, image}` with the loaded image.

  ## Examples

      iex> create_image_repair(moderator, "42")
      {:ok, %Image{}}

      iex> create_image_repair(user, "42")
      {:error, :unauthorized}

  """
  @spec create_image_repair(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()} | {:error, :ban | :unauthorized | :not_found}
  def create_image_repair(%Actor{} = actor, image_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :repair, image_id) do
      query = where(Image, id: ^image.id)

      Multi.new()
      |> Multi.update_all(:image_repair, query,
        set: [thumbnails_generated: false, processed: false]
      )
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        "Image.Repair:create",
        Paths.image_path(image),
        "Repaired image #{image.id}"
      )
      |> Multi.transact()
      |> case do
        {:ok, _changes} ->
          enqueue_image_repair(image)
          purge_files(image, image.hidden_image_key)
          {:ok, image}

        error ->
          error
      end
    end
  end

  @doc group: "Moderation and lifecycle"
  @doc """
  Hides (soft-deletes) the image named by `image_id` from public view, on behalf
  of `actor`, recording the deletion reason from `attrs`.

  The image is loaded by id and authorized for `:hide`. On success the image is
  hidden (its reports and duplicate reports closed, tag counts decremented,
  thumbnails purged, everything reindexed) and a moderation log is written attributing
  the deletion to `actor`.

  Returns `{:ok, image}` with the hidden image, or `{:error, changeset}` when
  the hide is rejected (e.g. a blank deletion reason), leaving the image visible.

  ## Examples

      iex> create_image_hide(moderator, "42", %{"deletion_reason" => "Rule violation"})
      {:ok, %Image{}}

      iex> create_image_hide(user, "42", %{"deletion_reason" => "Rule violation"})
      {:error, :unauthorized}

  """
  @spec create_image_hide(Actor.t(), IntegerId.integer_id(), map()) ::
          {:ok, Image.t()} | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def create_image_hide(%Actor{user: user} = actor, image_id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :hide, image_id) do
      changeset_fun = fn %{locked_image: image} -> Image.hide_changeset(image, attrs, user) end

      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> put_hide_image(changeset_fun, image, user)
      |> Galleries.put_remove_image_interactions(image)
      |> DuplicateReports.put_reject_image_reports(:duplicate_reports, image.id)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{image: hidden} ->
        {
          "Image.Delete:create",
          Paths.image_path(hidden),
          "Deleted image #{hidden.id} (#{hidden.deletion_reason})"
        }
      end)
      |> Multi.transact()
      |> case do
        {:ok, %{image: %Image{} = image}} ->
          {:ok, image}

        {:error, :image, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Moderation and lifecycle"
  @doc """
  Restores (unhides) the image named by `image_id` from moderation hiding, on
  behalf of `actor`.

  The image is loaded by id and authorized for `:unhide`. Restoring an image that
  is not hidden still succeeds (it is left visible). On success the image is
  made visible, its content reindexed, and a moderation log is written
  attributing the restore to `actor`.

  Returns `{:ok, image}` with the restored image.

  ## Examples

      iex> delete_image_user_hide(moderator, "42")
      {:ok, %Image{}}

      iex> delete_image_user_hide(user, "42")
      {:error, :unauthorized}

  """
  @spec delete_image_hide(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()} | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def delete_image_hide(%Actor{} = actor, image_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :unhide, image_id) do
      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> Multi.run(:hidden_image_key, fn _repo, %{locked_image: image} ->
        {:ok, image.hidden_image_key}
      end)
      |> Multi.update(:image, fn %{locked_image: image} ->
        Image.unhide_changeset(image)
      end)
      |> Multi.run(:tags, fn repo, %{image: image} ->
        {:ok, repo.preload(image, :tags, force: true).tags}
      end)
      |> Tags.put_image_count_delta(
        :tag_image_counts,
        fn %{tags: tags} -> Enum.map(tags, & &1.id) end,
        1
      )
      |> put_reindex_image(:image)
      |> Multi.on_commit(fn %{image: image, tags: tags} ->
        Comments.reindex_comments_on_image(image)
        {image, tags}
      end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{image: image} ->
        {"Image.Delete:delete", Paths.image_path(image), "Restored image #{image.id}"}
      end)
      |> Multi.transact()
      |> case do
        {:ok, %{image: %Image{} = image, tags: _tags, hidden_image_key: key}} ->
          spawn(fn -> Thumbnailer.unhide_thumbnails(image, key) end)
          purge_files(image, key)

          {:ok, image}

        {:error, :image, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Moderation and lifecycle"
  @doc """
  Removes the vote cast by the user named by `user_id` on the image named by
  `image_id`, on behalf of `actor`.

  The image is loaded by id and authorized for `:tamper`; the target user is then
  loaded by id. A non-castable or unknown user is is `{:error, :not_found}`, checked
  after image authorization. Removing a vote the user never cast still succeeds.
  On success the image is reindexed and a moderation log recording the removed vote
  type and target user is written.

  Returns `{:ok, image}` with the image.

  ## Examples

      iex> delete_user_vote(moderator, "42", "7")
      {:ok, %Image{}}

      iex> delete_user_vote(user, "42", "7")
      {:error, :unauthorized}

  """
  @spec delete_user_vote(
          actor :: Actor.t(),
          image_id :: IntegerId.integer_id(),
          user_id :: IntegerId.integer_id()
        ) ::
          {:ok, Image.t()} | {:error, :ban | :unauthorized | :not_found}
  def delete_user_vote(%Actor{} = actor, image_id, user_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :tamper, image_id),
         {:ok, user} <- Loader.fetch(User, user_id) do
      Multi.new()
      |> ImageVotes.delete_vote_for_loaded_image(image, user)
      |> ModerationLogs.put_log(:moderation_log, actor, fn changes ->
        vote_type = deleted_vote_type(changes)

        {
          "Image.Tamper:create",
          Paths.image_path(image),
          "Deleted #{vote_type} by #{user.name} on image #{image.id}"
        }
      end)
      |> Multi.on_commit(fn _changes -> reindex_image(image) end)
      |> Multi.transact()
      |> case do
        {:ok, _changes} -> {:ok, image}
        error -> error
      end
    end
  end

  @doc group: "Visibility and filtering"
  @doc """
  Returns whether `image` matches the viewer's compiled hide/spoiler policy.
  """
  @spec filter_or_spoiler_hits?(Image.t(), Philomena.Filters.ImageFilter.t()) :: boolean()
  def filter_or_spoiler_hits?(%Image{} = image, image_filter) do
    Filtering.filter_or_spoiler_hits?(image, image_filter)
  end

  @doc group: "Visibility and filtering"
  @doc """
  Verifies the Images-owned forced-filter prerequisite for a loaded image.

  This narrow cross-context service is used by comment actions after image
  authorization succeeds. Controllers must call their owning action instead.

  ## Examples

      iex> verify_forced_filter_access(actor, image)
      :ok

  """
  @spec verify_forced_filter_access(Actor.t(), Image.t()) ::
          :ok | {:error, :forced_filter}
  def verify_forced_filter_access(%Actor{} = actor, %Image{} = image) do
    Filtering.verify_not_forced(actor, image)
  end

  @doc group: "Metadata editing"
  @doc """
  Clears the original SHA-512 hash of the image named by `image_id`, on behalf
  of `actor`, allowing the same file to be uploaded again.

  The image is loaded by id and authorized for `:remove_hash`. On success the hash is
  cleared, the image is reindexed, and a moderation log is written attributing the
  change to `actor`.

  Returns `{:ok, image}` with the updated image.

  ## Examples

      iex> delete_image_hash(moderator, "42")
      {:ok, %Image{}}

      iex> delete_image_hash(user, "42")
      {:error, :unauthorized}

  """
  @spec delete_image_hash(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()} | {:error, :ban | :unauthorized | :not_found}
  def delete_image_hash(%Actor{} = actor, image_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :remove_hash, image_id) do
      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> Multi.update(:image, fn %{locked_image: image} -> Image.remove_hash_changeset(image) end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{image: image} ->
        {"Image.Hash:delete", Paths.image_path(image), "Cleared hash of image #{image.id}"}
      end)
      |> put_reindex_image(:image)
      |> Multi.transact()
      |> case do
        {:ok, %{image: %Image{} = image}} ->
          {:ok, image}
      end
    end
  end

  @doc group: "Metadata editing"
  @doc """
  Updates the moderation notes on the image named by `image_id`, on behalf of
  `actor`, from `attrs` (a map with a `"scratchpad"` key).

  The image is loaded by id and authorized for `:edit_scratchpad`. On success the notes are
  updated, the image is reindexed, and a moderation log is written attributing the
  change to `actor`.

  Returns `{:ok, image}` with the updated image.

  ## Examples

      iex> update_image_scratchpad(moderator, "42", %{"scratchpad" => "watch closely"})
      {:ok, %Image{}}

      iex> update_image_scratchpad(user, "42", %{"scratchpad" => "watch closely"})
      {:error, :unauthorized}

  """
  @spec update_image_scratchpad(Actor.t(), IntegerId.integer_id(), map()) ::
          {:ok, Image.t()} | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def update_image_scratchpad(%Actor{} = actor, image_id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :edit_scratchpad, image_id) do
      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> Multi.update(:image, fn %{locked_image: image} ->
        Image.scratchpad_changeset(image, attrs)
      end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{image: image} ->
        {
          "Image.Scratchpad:update",
          Paths.image_path(image),
          "Updated mod notes on image #{image.id} (#{image.scratchpad})"
        }
      end)
      |> put_reindex_image(:image)
      |> Multi.transact()
      |> case do
        {:ok, %{image: %Image{} = image}} ->
          {:ok, image}

        {:error, :image, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Metadata editing"
  @doc """
  Deletes the source change history of the image named by `image_id`, on behalf
  of `actor`.

  The image is loaded by id and authorized for `:remove_source_history`. On success the source history
  is removed, the image is reindexed, and a moderation log is written attributing
  the deletion to `actor`.

  Returns `{:ok, image}` with the updated image.

  ## Examples

      iex> delete_image_source_history(moderator, "42")
      {:ok, %Image{}}

      iex> delete_image_source_history(user, "42")
      {:error, :unauthorized}

  """
  @spec delete_image_source_history(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()} | {:error, :ban | :unauthorized | :not_found}
  def delete_image_source_history(%Actor{} = actor, image_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <-
           load_image_member(actor, :remove_source_history, image_id, [:source_changes]) do
      query = Image |> where(id: ^image.id) |> preload(:source_changes)

      Multi.new()
      |> Multi.lock_one(:locked_image, query)
      |> Multi.update(:image, fn %{locked_image: image} ->
        Image.remove_source_history_changeset(image)
      end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{image: image} ->
        {
          "Image.SourceHistory:delete",
          Paths.image_path(image),
          "Deleted source history for image #{image.id}"
        }
      end)
      |> put_reindex_image(:image)
      |> Multi.transact()
      |> case do
        {:ok, %{image: %Image{} = image}} ->
          {:ok, image}
      end
    end
  end

  @doc group: "Metadata editing"
  @doc """
  Replaces the file content of the image named by `image_id`, on behalf of
  `actor`, from `attrs` (a map with an `"image"` upload).

  The image is loaded by id and authorized for `:replace_file`. On success the
  file is replaced, thumbnails are regenerated in the image's current storage
  path, old files are purged, the image is reindexed, and a moderation log is
  written attributing the change to `actor`.

  Returns `{:ok, image}` with the updated image, or
  `{:error, %Ecto.Changeset{}}` when the replacement is rejected (e.g. no file,
  or a file already uploaded as another image), leaving the image untouched.

  ## Examples

      iex> update_image_file(moderator, "42", upload)
      {:ok, %Image{}}

      iex> update_image_file(user, "42", upload)
      {:error, :unauthorized}

  """
  @spec update_image_file(Actor.t(), IntegerId.integer_id(), PhilomenaMedia.Upload.t() | nil) ::
          {:ok, Image.t()}
          | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def update_image_file(%Actor{} = actor, image_id, upload) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :replace_file, image_id) do
      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> Multi.update(:image, fn %{locked_image: image} ->
        image
        |> Image.changeset(%{})
        |> Uploader.analyze_upload(upload)
      end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{image: image} ->
        {"Image.File:update", Paths.image_path(image), "Updated file of image #{image.id}"}
      end)
      |> put_reindex_image(:image)
      |> Multi.transact()
      |> case do
        {:ok, %{image: %Image{} = image}} ->
          Uploader.persist_upload(image)
          repair_image(image)
          purge_files(image, image.hidden_image_key)

          {:ok, image}

        {:error, :image, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Metadata editing"
  @doc """
  Updates the description of the image named by `image_id`, on behalf of
  `actor`, from `attrs` (a map with a `"description"` key).

  Banned actors are rejected first with `{:error, :ban}` (a write with no
  fingerprint is `{:error, :unauthorized}`). The image is then loaded by id and
  authorized for `:edit_description`. The uploader may edit a non-hidden image
  whose description editing is allowed, and staff may edit any image.

  Returns `{:ok, {image, old_description}}` with the updated image (its author,
  sources, and tags preloaded) and the description it replaced. The context
  broadcasts the description and image updates after persistence. Returns
  `{:error, %Ecto.Changeset{}}` when the new
  description is rejected (e.g. too long), leaving the image untouched.

  ## Examples

      iex> update_image_description(actor, "42", %{"description" => "New description"})
      {:ok, {%Image{}, "Old description"}}

      iex> update_image_description(actor, "42", %{"description" => "..."})
      {:error, :unauthorized}

  """
  @spec update_image_description(Actor.t(), IntegerId.integer_id(), map()) ::
          {:ok, {Image.t(), String.t() | nil}}
          | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def update_image_description(%Actor{} = actor, image_id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, image_id} <- Loader.parse_id(image_id) do
      Multi.new()
      |> put_lock_image(actor, image_id, :edit_description, [:user, :sources, tags: :aliases])
      |> Multi.update(:image, fn %{locked_image: image} ->
        Image.description_changeset(image, attrs)
      end)
      |> put_reindex_image(:image)
      |> Multi.transact()
      |> case do
        {:ok, %{locked_image: %Image{} = old_image, image: %Image{} = image}} ->
          broadcast_description_update(image, old_image.description)

          {:ok, {image, old_image.description}}

        {:error, :image, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc group: "Metadata editing"
  @doc """
  Updates the sources of the image named by `image_id`, on behalf of `actor`,
  from `attrs` (`"old_sources"`/`"sources"` maps),
  recording source change records attributed to the actor.

  Banned actors are rejected first with `{:error, :ban}` (a write with no
  fingerprint is `{:error, :unauthorized}`), before the image is loaded. A
  non-exempt actor who has updated metadata within the last 5 seconds gets
  `{:error, :rate_limited}` during the transaction reservation. The image is
  loaded by id (with its author, sources, and tags preloaded) and authorized
  for `:edit_metadata` before that reservation. Sources are editable on a
  non-hidden image by anyone (anonymous included). On success the sources are
  updated and attributed, the actor's metadata-update stat is incremented when
  sources actually changed, and the image is reindexed.

  Returns `{:ok, %{image: image, source_change_count: count}}`. The context
  broadcasts the source and image updates after persistence. Returns
  `{:error, %Ecto.Changeset{}}` when
  the update is rejected (e.g. more than the allowed number of sources), leaving
  the image untouched.

  ## Examples

      iex> update_image_sources(actor, "42", %{"old_sources" => %{}, "sources" => %{"0" => %{"source" => "http://example.com"}}})
      {:ok, %{image: %Image{}, source_change_count: 1}}

  """
  @spec update_image_sources(Actor.t(), IntegerId.integer_id(), map()) ::
          {:ok,
           %{
             image: Image.t(),
             source_change_count: non_neg_integer()
           }}
          | {:error, :ban | :unauthorized | :not_found | :rate_limited | Ecto.Changeset.t()}
  def update_image_sources(%Actor{} = actor, image_id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :edit_metadata, image_id, [:sources]),
         {:ok, source_input_form} <-
           %SourceInputForm{}
           |> SourceInputForm.changeset(attrs)
           |> SourceInputForm.apply(image) do
      case update_loaded_sources(image, actor, source_input_form) do
        {:ok, %Image{} = image} ->
          {:ok,
           %{
             image: image,
             source_change_count: SourceChanges.count_for_image(image)
           }}

        {:error, :no_change} ->
          {:ok,
           %{
             image: image,
             source_change_count: SourceChanges.count_for_image(image)
           }}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:error, changeset}

        error ->
          error
      end
    end
  end

  @doc group: "Metadata editing"
  @doc """
  Updates the locked tag list of the image named by `image_id`, on behalf of
  `actor`, from `attrs` (a map with a `"tag_input"` key).

  The image is loaded by id and authorized for `:lock_tags`. A blank `tag_input` clears
  the list. On success the locked tags are replaced, the image is reindexed, and a
  moderation log is written attributing the change to `actor`. Only existing tags
  are considered; aliases resolve to their canonical tags and implications are not
  expanded.

  Returns `{:ok, image}` with the updated image.

  ## Examples

      iex> update_image_locked_tags(moderator, "42", %{"tag_input" => "safe, solo"})
      {:ok, %Image{}}

      iex> update_image_locked_tags(user, "42", %{"tag_input" => "safe, solo"})
      {:error, :unauthorized}

  """
  @spec update_image_locked_tags(Actor.t(), IntegerId.integer_id(), map()) ::
          {:ok, Image.t()} | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def update_image_locked_tags(%Actor{} = actor, image_id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :lock_tags, image_id, [:locked_tags]),
         {:ok, tag_input_form} <-
           %TagInputForm{}
           |> TagInputForm.changeset(attrs)
           |> TagInputForm.apply(image) do
      tag_names = Tag.parse_tag_list(tag_input_form.tag_input)

      image_query =
        Image
        |> where(id: ^image.id)
        |> preload(:locked_tags)

      Multi.new()
      |> Multi.lock_one(:locked_image, image_query)
      |> Tags.put_canonicalize_tag_name_sets([{:tags, tag_names, []}])
      |> Multi.update(:image, fn %{locked_image: image, canonical_tags: %{tags: tags}} ->
        Image.locked_tags_changeset(image, attrs, tags)
      end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{image: image} ->
        {
          "Image.TagLock:update",
          Paths.image_path(image),
          "Updated list of locked tags on image #{image.id}"
        }
      end)
      |> put_reindex_image(:image)
      |> Multi.transact_with_automatic_retry()
      |> case do
        {:ok, %{image: %Image{} = image}} ->
          {:ok, image}

        {:error, :image, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Metadata editing"
  @doc """
  Updates the tags of the image named by `image_id`, on behalf of `actor`, from
  `attrs` (`"old_tag_input"`/`"tag_input"`), recording tag
  change records attributed to the actor.

  Banned actors are rejected first with `{:error, :ban}` (a write with no
  fingerprint is `{:error, :unauthorized}`), before the image is loaded. A
  non-exempt actor who has updated metadata within the last 5 seconds gets
  `{:error, :rate_limited}` from the transaction reservation. The image is
  loaded by id (with its author, locked tags, sources, and tags preloaded) and
  authorized for `:edit_metadata` before that reservation - editable on a
  non-hidden image whose tag editing is allowed by anyone (anonymous
  included), so an image with tag editing disabled is
  `{:error, :unauthorized}`. On success the tags are updated and attributed,
  the image, its comments, and the affected tags are reindexed, and the
  actor's metadata-update stat is incremented when tags actually changed.

  On success, returns `{:ok, %{image: image, tag_change_count: count,
  tag_change_tag_count: tag_count}}`. The context broadcasts the tag and image
  updates after persistence.

  ## Failure shapes

  - `{:error, %Ecto.Changeset{}}` when the update is rejected (e.g. the
    image would drop below the minimum tag count)
  - `{:error, :rate_limited}` from either of two independent
    counters - the once-per-window check above, or the
    in-transaction `TagChanges.Limits` check that caps the number of tag and
    rating changes over ten minutes and rolls back at the
    `:check_limits` step.

  All failures leave the image untouched.

  ## Examples

      iex> update_image_tags(actor, "42", %{"old_tag_input" => "safe", "tag_input" => "safe, cute"})
      {:ok, %{image: %Image{}, tag_change_count: 1, tag_change_tag_count: 1}}

  """
  @spec update_image_tags(Actor.t(), IntegerId.integer_id(), map()) ::
          {:ok,
           %{
             image: Image.t(),
             tag_change_count: non_neg_integer(),
             tag_change_tag_count: non_neg_integer()
           }}
          | {:error,
             :ban
             | :unauthorized
             | :not_found
             | :rate_limited
             | Ecto.Changeset.t()}
  def update_image_tags(%Actor{} = actor, image_id, attrs) do
    # Unchanged and invalid submissions re-render the tags partial from this
    # image, so it needs the same associations as the locked, updated one.
    with :ok <- verify_write_access(actor),
         {:ok, image} <-
           load_image_member(actor, :edit_metadata, image_id, [:tags, :locked_tags]),
         {:ok, tag_input_form} <-
           %TagInputForm{}
           |> TagInputForm.changeset(attrs)
           |> TagInputForm.apply(image) do
      case update_loaded_tags(image, actor, tag_input_form) do
        {:ok, %Image{} = image} ->
          {tag_change_count, tag_change_tag_count} = TagChanges.count_for_image(image)

          {:ok,
           %{
             image: image,
             tag_change_count: tag_change_count,
             tag_change_tag_count: tag_change_tag_count
           }}

        {:error, :no_change} ->
          {tag_change_count, tag_change_tag_count} = TagChanges.count_for_image(image)

          {:ok,
           %{
             image: image,
             tag_change_count: tag_change_count,
             tag_change_tag_count: tag_change_tag_count
           }}

        {:error, :rate_limited} ->
          {:error, :rate_limited}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:error, changeset}

        error ->
          error
      end
    end
  end

  @doc group: "Metadata editing"
  @doc """
  Reassigns the uploader of the image named by `image_id`, on behalf of `actor`,
  from `image_params`.

  `image_params` is a map with a `"username"` key. A blank username clears the
  uploader, anonymizing it.

  Authorization requires both `:show` on `:identity_metadata` and
  `:update_uploader` on the loaded image. The identity capability is checked
  first; malformed and missing image ids are otherwise `{:error, :not_found}`.
  On success the uploader is reassigned, the image and its tag changes are
  reindexed, and a moderation log is written attributing the change to `actor`.

  Returns `{:ok, image}` with the updated image (its new uploader and their awards
  preloaded), `{:error, :invalid_params}` when `image_params` is not
  a map, or `{:error, %Ecto.Changeset{}}` when the username names no user, both
  leaving the image untouched.

  ## Examples

      iex> update_image_uploader(moderator, "42", %{"username" => "Admin"})
      {:ok, %Image{}}

      iex> update_image_uploader(user, "42", %{"username" => "Admin"})
      {:error, :unauthorized}

  """
  @spec update_image_uploader(Actor.t(), IntegerId.integer_id(), any()) ::
          {:ok, Image.t()}
          | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def update_image_uploader(%Actor{} = actor, image_id, image_params) do
    with :ok <- authorize(actor, :show, :identity_metadata),
         :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :update_uploader, image_id),
         {:ok, image} <-
           image
           |> Image.username_changeset(image_params)
           |> Ecto.Changeset.apply_action(:update) do
      username = image.username

      uploader =
        if username do
          case Users.load_active_user_by_name(actor, username) do
            {:ok, user} -> user
            _error -> nil
          end
        end

      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> Multi.update(:image, fn %{locked_image: image} ->
        Image.uploader_changeset(image, username, uploader)
      end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{image: image} ->
        {
          "Image.Uploader:update",
          Paths.image_path(image),
          "Changed uploader of image #{image.id}"
        }
      end)
      |> put_reindex_image(:image)
      |> Multi.on_commit(fn %{image: image} -> TagChanges.reindex_tag_changes_on_image(image) end)
      |> Multi.transact()
      |> case do
        {:ok, %{image: %Image{} = image}} ->
          {:ok, Repo.preload(image, user: [awards: :badge])}

        {:error, :image, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Metadata editing"
  @doc """
  Sets or clears the anonymity status of the image named by `image_id`,
  on behalf of `actor`.

  Authorization requires both `:show` on `:identity_metadata` and
  `:update_anonymous` on the loaded image. The identity capability is checked
  first; malformed and missing image ids are otherwise `{:error, :not_found}`.
  On success the anonymity is toggled, the image and its tag changes are
  reindexed, and a moderation log is written attributing the change to `actor`.

  Returns `{:ok, image}` with the updated image.

  ## Examples

      iex> update_image_anonymous(moderator, "42", true)
      {:ok, %Image{}}

      iex> update_image_anonymous(user, "42", true)
      {:error, :unauthorized}

  """
  @spec update_anonymous(Actor.t(), IntegerId.integer_id(), boolean()) ::
          {:ok, Image.t()} | {:error, :ban | :unauthorized | :not_found}
  def update_anonymous(%Actor{} = actor, image_id, anonymous?) do
    with :ok <- authorize(actor, :show, :identity_metadata),
         :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :update_anonymous, image_id) do
      log_type = if anonymous?, do: "Image.Anonymous:create", else: "Image.Anonymous:delete"

      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> Multi.update(:image, fn %{locked_image: image} ->
        Image.anonymous_changeset(image, %{anonymous: anonymous?})
      end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{image: image} ->
        {log_type, Paths.image_path(image), "Updated anonymity of image #{image.id}"}
      end)
      |> put_reindex_image(:image)
      |> Multi.on_commit(fn %{image: image} -> TagChanges.reindex_tag_changes_on_image(image) end)
      |> Multi.transact()
      |> case do
        {:ok, %{image: %Image{} = image}} ->
          {:ok, image}
      end
    end
  end

  @doc group: "Metadata editing"
  @doc """
  Updates the deletion reason of the image named by `image_id`, on behalf of
  `actor`, from `attrs`.

  The image is loaded by id and authorized for `:update_hide_reason`. Only an already-hidden
  image may have its reason changed; a visible image is `{:error, :not_deleted}`,
  left untouched. On success the reason is updated, the image is reindexed, and
  a moderation log is written attributing the change to `actor`.

  Returns `{:ok, image}` with the updated image, or `{:error, %Ecto.Changeset{}}`
  when the new reason is rejected (e.g. blank), leaving the image untouched.

  ## Examples

      iex> update_image_hide(moderator, "42", %{"deletion_reason" => "Duplicate"})
      {:ok, %Image{}}

      iex> update_image_hide(user, "42", %{"deletion_reason" => "Duplicate"})
      {:error, :unauthorized}

  """
  @spec update_image_hide(Actor.t(), IntegerId.integer_id(), map()) ::
          {:ok, Image.t()}
          | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def update_image_hide(%Actor{} = actor, image_id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :update_hide_reason, image_id) do
      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> Multi.update(:image, fn %{locked_image: image} ->
        Image.hide_reason_changeset(image, attrs)
      end)
      |> ModerationLogs.put_log(:moderation_log, actor, fn %{image: image} ->
        {
          "Image.Delete:update",
          Paths.image_path(image),
          "Changed deletion reason of #{image.id} (#{image.deletion_reason})"
        }
      end)
      |> put_reindex_image(:image)
      |> Multi.transact()
      |> case do
        {:ok, %{image: %Image{} = image}} ->
          {:ok, image}

        {:error, :image, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc group: "Bulk operations"
  @doc """
  Applies a batch tag edit to `image_ids` on behalf of `actor`.

  Authorizes `:batch_update` against the tag model, parses the tag list and
  image IDs, and runs the batch update in chunks of 1,000 IDs. Batch tagging is
  a staff feature and is not rate-limited. Each successful chunk writes an
  `"Admin.Batch.Tag:update"` moderation log and broadcasts its update to the
  firehose.

  On success returns `{:ok, result}` where `result` is a map with:

    * `:succeeded` - the number of image IDs successfully updated;
    * `:failed` - the number of image IDs in failed chunks, matching no image,
      or inaccessible to the actor.

  Returns `{:error, :unauthorized}` when `actor` may not batch-tag, or an
  invalid `BatchTagForm` changeset when the parameters cannot be cast.
  """
  @spec update_batch_tags(Actor.t(), map()) ::
          {:ok, %{succeeded: non_neg_integer(), failed: non_neg_integer()}}
          | {:error, :unauthorized | Ecto.Changeset.t()}
  def update_batch_tags(%Actor{} = actor, params) do
    with :ok <- authorize(actor, :batch_update, Tag),
         {:ok, form} <-
           %BatchTagForm{}
           |> BatchTagForm.changeset(params)
           |> Ecto.Changeset.apply_action(:create) do
      tag_names = Tag.parse_tag_list(form.tag_list)

      added_names = Enum.reject(tag_names, &String.starts_with?(&1, "-"))

      removed_names =
        tag_names
        |> Enum.filter(&String.starts_with?(&1, "-"))
        |> Enum.map(&String.replace_leading(&1, "-", ""))

      attributes = %{
        ip: actor.ip,
        fingerprint: actor.fingerprint,
        user_id: actor.user.id
      }

      form.image_ids
      |> Enum.chunk_every(@batch_tag_size)
      |> Enum.reduce({0, 0}, fn image_ids, {succeeded, failed} ->
        Multi.new()
        |> put_batch_tag(actor, image_ids, added_names, removed_names, attributes)
        |> ModerationLogs.put_log(:moderation_log, actor, fn %{locked_image_ids: image_ids} ->
          {
            "Admin.Batch.Tag:update",
            Paths.profile_path(actor.user),
            "Batch tagged '#{form.tag_list}' on #{Enum.count(image_ids)} images"
          }
        end)
        |> Multi.transact_with_automatic_retry()
        |> case do
          {:ok, %{locked_image_ids: processed_ids}} ->
            unprocessed_ids = image_ids -- processed_ids

            {succeeded + Enum.count(processed_ids), failed + Enum.count(unprocessed_ids)}

          _error ->
            {succeeded, failed + Enum.count(image_ids)}
        end
      end)
      |> then(fn {succeeded, failed} ->
        {:ok, %{succeeded: succeeded, failed: failed}}
      end)
    end
  end

  @doc group: "Bulk operations"
  @doc """
  Applies the net inverse of selected tag-change entries to multiple images.

  `changes` contains one or more ordered `:tag_changes` entries for each image.
  Each entry is resolved through its locked alias family and the entries are
  reduced to one physical tag edit per image. An entry that adds a tag is
  inverted by removing its alias family; an entry that removes a tag is
  inverted by adding the current canonical tag when the family is absent. At
  most one new tag-change row is created for each affected image.

  Images are locked before tag aliases and current taggings are read, matching
  the lock order used by batched alias migration. This allows a reversion to
  observe either the source or canonical physical tagging without creating a
  duplicate or losing an inverse removal.
  """
  @spec batch_revert([map()], map()) :: {:ok, [integer()]} | :error
  def batch_revert(changes, attributes) do
    Multi.new()
    |> put_batch_revert_tag_changes(changes, attributes)
    |> Multi.transact_with_automatic_retry()
    |> case do
      {:ok, %{locked_image_ids: image_ids}} ->
        {:ok, image_ids}

      _error ->
        :error
    end
  end

  @doc group: "Background jobs"
  @doc """
  Executes the worker-side CDN purge operation for image files.

  Calls the system purge-cache command to remove the specified files from the CDN cache.

  ## Examples

      iex> perform_purge(["file1.jpg", "file2.jpg"])
      :ok

  """
  @spec perform_purge([String.t()]) :: :ok
  def perform_purge(files) do
    {_out, 0} = System.cmd("purge-cache", [JSON.encode!(%{files: files})])

    :ok
  end

  @doc group: "Background jobs"
  @doc """
  Persists metadata calculated by the thumbnail worker.

  The worker supplies derived attributes and a processing stage.
  """
  @spec update_thumbnail_metadata!(Image.t(), map(), :thumbnail | :process) :: Image.t()
  def update_thumbnail_metadata!(%Image{} = image, attrs, :thumbnail) do
    image
    |> Image.thumbnail_changeset(attrs)
    |> Repo.update!()
  end

  def update_thumbnail_metadata!(%Image{} = image, attrs, :process) do
    image
    |> Image.process_changeset(attrs)
    |> Repo.update!()
  end

  @doc group: "Background jobs"
  @doc """
  Replaces attribution data on a user's images in batches.
  """
  @spec wipe_user_attribution!(integer(), term(), String.t()) :: :ok
  def wipe_user_attribution!(user_id, ip, fingerprint) do
    Image
    |> where(user_id: ^user_id)
    |> Batch.query_batches()
    |> Enum.each(&Repo.update_all(&1, set: [ip: ip, fingerprint: fingerprint]))

    :ok
  end

  @doc group: "Background jobs"
  @doc """
  Decrements vote counters for the supplied images after user vote cleanup.
  """
  @spec decrement_vote_counters!([integer()], boolean()) :: {non_neg_integer(), nil}
  def decrement_vote_counters!(image_ids, true) when is_list(image_ids) do
    Repo.update_all(where(Image, [image], image.id in ^image_ids),
      inc: [upvotes_count: -1, score: -1]
    )
  end

  def decrement_vote_counters!(image_ids, false) when is_list(image_ids) do
    Repo.update_all(where(Image, [image], image.id in ^image_ids),
      inc: [downvotes_count: -1, score: 1]
    )
  end

  @doc group: "Background jobs"
  @doc """
  Decrements favorite counters for the supplied images after user favorite
  cleanup.
  """
  @spec decrement_fave_counters!([integer()]) :: {non_neg_integer(), nil}
  def decrement_fave_counters!(image_ids) when is_list(image_ids) do
    Repo.update_all(where(Image, [image], image.id in ^image_ids), inc: [faves_count: -1])
  end

  @doc group: "Subscriptions and notifications"
  @doc """
  Subscribes `actor` to the image named by `image_id`, so they are notified of
  new comments on it.

  The image is loaded by id and authorized for `:subscribe`. Subscribing is
  idempotent and, as subscription management, is deliberately exempt from
  `verify_write_access/1`. The image is reindexed so `my:subs` finds it.

  Returns `{:ok, image}`, or `{:error, %Ecto.Changeset{}}` if the subscription
  insert is rejected.

  ## Examples

      iex> create_image_subscription(user, "42")
      {:ok, %Image{}}

      iex> create_image_subscription(user, "999999999")
      {:error, :not_found}

  """
  @spec create_image_subscription(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()} | {:error, :unauthorized | :not_found | Ecto.Changeset.t()}
  def create_image_subscription(%Actor{} = actor, image_id) do
    with {:ok, image} <- load_image_member(actor, :subscribe, image_id),
         {:ok, _subscription} <- create_subscription(image, actor.user) do
      {:ok, reindex_image(image)}
    end
  end

  @doc group: "Subscriptions and notifications"
  @doc """
  Unsubscribes `actor` from the image named by `image_id`.

  Loading and authorization mirror `create_image_subscription/2`. Unsubscribing is
  idempotent and cannot fail, so there is no changeset error shape. Like
  subscription creation, deletion is deliberately exempt from
  `verify_write_access/1` and reindexes the image.

  Returns `{:ok, image}`, `{:error, :unauthorized}`, or `{:error, :not_found}`.

  ## Examples

      iex> delete_image_subscription(user, "42")
      {:ok, %Image{}}

  """
  @spec delete_image_subscription(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()} | {:error, :unauthorized | :not_found}
  def delete_image_subscription(%Actor{} = actor, image_id) do
    with {:ok, image} <- load_image_member(actor, :unsubscribe, image_id) do
      # Deletion is idempotent and cannot fail; the hard match crashes if it does.
      {:ok, _subscription} = delete_subscription(image, actor.user)
      {:ok, reindex_image(image)}
    end
  end

  @doc group: "Subscriptions and notifications"
  @doc """
  Clears `actor`'s unread notifications for the image named by `image_id`.

  This personal read-state operation is deliberately exempt from
  `verify_write_access/1`. The image is loaded before `:mark_read`
  authorization, which allows dismissing notifications even when the image
  is hidden. Missing IDs are actor-independent.

  Returns `{:ok, image}` after clearing `actor`'s image comment and image merge
  notifications for it.

  ## Examples

      iex> create_image_read(user, "42")
      {:ok, %Image{}}

      iex> create_image_read(user, "nonexistent")
      {:error, :not_found}

  """
  @spec create_image_read(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()} | {:error, :unauthorized | :not_found}
  def create_image_read(%Actor{} = actor, image_id) do
    with {:ok, image} <- load_image_member(actor, :mark_read, image_id) do
      clear_image_notification(image, actor.user)
      {:ok, image}
    end
  end

  @doc group: "User interactions"
  @doc """
  Records a personal hide of the image named by `image_id` for `actor`, so the
  image is filtered out of `actor`'s browsing. This is the per-user hide
  interaction, distinct from the moderator hide `hide_image/3`.

  Banned actors are rejected first with `{:error, :ban}` (a write with no
  fingerprint is `{:error, :unauthorized}`), before the image is loaded. The
  image is then loaded by id and authorized for `:vote`. Hiding is
  idempotent.

  Returns `{:ok, image}` with the image reloaded.

  ## Examples

      iex> create_image_user_hide(actor, "42")
      {:ok, %Image{}}

  """
  @spec create_image_user_hide(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()} | {:error, :ban | :unauthorized | :not_found}
  def create_image_user_hide(actor, image_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :vote, image_id) do
      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> ImageHides.put_hide_for_loaded_image(image, actor.user)
      |> Multi.transact()
      |> case do
        {:ok, _changes} ->
          {:ok, Repo.reload!(image)}
      end
    end
  end

  @doc group: "User interactions"
  @doc """
  Removes `actor`'s personal hide of the image named by `image_id`. This is the
  per-user unhide interaction, distinct from the moderator unhide `unhide_image/2`.

  Loading, authorization, and ban semantics mirror `create_image_hide/2`.
  Removing a hide is idempotent.

  Returns `{:ok, image}` with the image reloaded.

  ## Examples

      iex> delete_image_user_hide(actor, "42")
      {:ok, %Image{}}

  """
  @spec delete_image_user_hide(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()} | {:error, :ban | :unauthorized | :not_found}
  def delete_image_user_hide(actor, image_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image_member(actor, :vote, image_id) do
      Multi.new()
      |> ImageHides.delete_hide_for_loaded_image(image, actor.user)
      |> Multi.transact()
      |> case do
        {:ok, _changes} ->
          {:ok, Repo.reload!(image)}
      end
    end
  end

  @doc group: "User interactions"
  @doc """
  Records `actor`'s fave of `image_id`, which also casts an implicit upvote
  (replacing an existing downvote). Faving is idempotent.

  Write access, image authorization, and forced-filter enforcement happen before
  the transaction.

  ## Examples

      iex> create_image_fave(actor, "42")
      {:ok, %Image{}}

  """
  @spec create_image_fave(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()}
          | {:error, :ban | :unauthorized | :not_found | :forced_filter}
  def create_image_fave(%Actor{user: user} = actor, image_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <-
           load_image_member(actor, :vote, image_id, [:sources, tags: :aliases]),
         :ok <- Filtering.verify_not_forced(actor, image) do
      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> ImageFaves.put_fave_for_loaded_image(image, user)
      |> ImageVotes.put_vote_for_loaded_image(image, user, true)
      |> Multi.transact()
      |> case do
        {:ok, _changes} ->
          {:ok, Repo.reload!(image)}
      end
    end
  end

  @doc group: "User interactions"
  @doc """
  Removes `actor`'s fave of `image_id`, leaving any upvote in place. Unfaving is
  idempotent and enforces the same prerequisites as `create_fave/2`.

  Returns `{:ok, image}` with the image reloaded.

  ## Examples

      iex> delete_image_fave(actor, "42")
      {:ok, %Image{}}

  """
  @spec delete_image_fave(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()}
          | {:error, :ban | :unauthorized | :not_found | :forced_filter}
  def delete_image_fave(%Actor{user: user} = actor, image_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <-
           load_image_member(actor, :vote, image_id, [:sources, tags: :aliases]),
         :ok <- Filtering.verify_not_forced(actor, image) do
      Multi.new()
      |> ImageFaves.delete_fave_for_loaded_image(image, user)
      |> Multi.transact()
      |> case do
        {:ok, _changes} ->
          {:ok, Repo.reload!(image)}
      end
    end
  end

  @doc group: "User interactions"
  @doc """
  Records `actor`'s vote on `image_id` from `attrs`, replacing any existing
  vote. The `up` parameter accepts booleans and their form-encoded string
  values. Invalid attributes return their vote form changeset. Voting is
  idempotent.

  Write access, image authorization, and forced-filter enforcement happen before
  the transaction.

  ## Examples

      iex> create_image_vote(actor, "42", %{"up" => "1"})
      {:ok, %Image{}}

  """
  @spec create_image_vote(Actor.t(), IntegerId.integer_id(), map()) ::
          {:ok, Image.t()}
          | {:error,
             :ban
             | :unauthorized
             | :not_found
             | :forced_filter
             | Ecto.Changeset.t()}
  def create_image_vote(%Actor{user: user} = actor, image_id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <-
           load_image_member(actor, :vote, image_id, [:sources, tags: :aliases]),
         :ok <- Filtering.verify_not_forced(actor, image),
         {:ok, %{up: up}} <-
           %VoteForm{}
           |> VoteForm.changeset(attrs)
           |> VoteForm.apply(image) do
      Multi.new()
      |> Multi.lock_one(:locked_image, where(Image, id: ^image.id))
      |> ImageVotes.put_vote_for_loaded_image(image, user, up)
      |> Multi.transact()
      |> case do
        {:ok, _changes} ->
          {:ok, Repo.reload!(image)}
      end
    end
  end

  @doc group: "User interactions"
  @doc """
  Removes `actor`'s vote on `image_id`. Unvoting is idempotent and enforces the
  same prerequisites as `create_vote/3`.

  Returns `{:ok, image}` with the image reloaded.

  ## Examples

      iex> delete_image_vote(actor, "42")
      {:ok, %Image{}}

  """
  @spec delete_image_vote(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Image.t()}
          | {:error, :ban | :unauthorized | :not_found | :forced_filter}
  def delete_image_vote(%Actor{user: user} = actor, image_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <-
           load_image_member(actor, :vote, image_id, [:sources, tags: :aliases]),
         :ok <- Filtering.verify_not_forced(actor, image) do
      Multi.new()
      |> ImageVotes.delete_vote_for_loaded_image(image, user)
      |> Multi.transact()
      |> case do
        {:ok, _changes} ->
          {:ok, Repo.reload!(image)}
      end
    end
  end

  @doc group: "User interactions"
  @doc """
  Assembles the interaction listing for the image named by `image_id`, on behalf
  of `actor`.

  The image is loaded by id and authorized for `:index` (visible for any
  non-hidden image, and to staff for hidden ones).

  The image is returned with its faves preloaded. Votes and hides are loaded and
  `has_votes` is `true` only when `actor` may `:tamper` with the image;
  otherwise `has_votes` is `false` and those associations are not fetched.

  Returns `{:ok, {image, has_votes}}`.

  ## Examples

      iex> list_image_faves(moderator, "42")
      {:ok, {%Image{}, true}}

      iex> list_image_faves(user, "42")
      {:ok, {%Image{}, false}}

  """
  @spec list_image_faves(Actor.t(), IntegerId.integer_id()) ::
          {:ok, {Image.t(), boolean()}} | {:error, :unauthorized | :not_found}
  def list_image_faves(%Actor{} = actor, image_id) do
    with {:ok, image} <- load_image_member(actor, :index, image_id, faves: :user) do
      case authorize(actor, :tamper, image) do
        :ok ->
          {:ok, {Repo.preload(image, upvotes: :user, downvotes: :user, hides: :user), true}}

        {:error, :unauthorized} ->
          {:ok, {image, false}}
      end
    end
  end

  # Invoked dynamically by the shared subscription implementation.
  @doc false
  @spec clear_image_notification(Image.t(), User.t() | nil) :: :ok
  def clear_image_notification(%Image{} = image, user) do
    Notifications.clear_image_comment(image, user)
    Notifications.clear_image_merge(image, user)
    :ok
  end

  @doc group: "Search indexing"
  @doc """
  Updates image search indices when a user's name changes.

  ## Examples

      iex> user_name_reindex("old_username", "new_username")
      :ok

  """
  @spec user_name_reindex(String.t(), String.t()) :: term()
  def user_name_reindex(old_name, new_name) do
    data = Images.SearchIndex.user_name_update_by_query(old_name, new_name)

    Search.update_by_query(Image, data.query, data.set_replacements, data.replacements)
  end

  @doc group: "Search indexing"
  @doc """
  Adds an after-commit image reindex step to a transaction workflow.

  The referenced step must resolve to an image. The indexing job is enqueued
  only after the database transaction commits.
  """
  @spec put_reindex_image(Multi.t(), Ecto.Multi.name()) :: Multi.t()
  def put_reindex_image(%Multi{} = multi, step) do
    Multi.on_commit(multi, fn %{^step => image} -> reindex_image(image) end)
  end

  @doc group: "Search indexing"
  @doc """
  Loads an image for an invariant-enforced indexing job.

  This worker service raises when the queued image no longer exists; request
  paths must use an actor-scoped loader instead.

  ## Examples

      iex> load_image_for_reindex!(42)
      %Image{}

  """
  @spec load_image_for_reindex!(integer()) :: Image.t()
  def load_image_for_reindex!(image_id) when is_integer(image_id) do
    Repo.one!(Image |> where(id: ^image_id) |> preload(:tags))
  end

  @doc group: "Search indexing"
  @doc """
  Queues a single image for search index updates.
  Returns the image struct unchanged, for use in a pipeline.

  ## Examples

      iex> reindex_image(image)
      %Image{}

  """
  @spec reindex_image(Image.t()) :: Image.t()
  def reindex_image(%Image{} = image) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Images", "id", [image.id]])

    image
  end

  @doc group: "Search indexing"
  @doc """
  Queues all listed image IDs for search index updates.
  Returns the list unchanged, for use in a pipeline.

  ## Examples

      iex> reindex_images([1, 2, 3])
      [1, 2, 3]

  """
  @spec reindex_images([integer()]) :: [integer()]
  def reindex_images(image_ids) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Images", "id", image_ids])

    image_ids
  end

  @doc group: "Search indexing"
  @doc """
  Returns the preload configuration for image indexing.

  Specifies which associations should be preloaded when indexing images,
  optimizing the queries for better performance.

  ## Examples

      iex> indexing_preloads()
      [sources: query, user: query, ...]

  """
  @spec indexing_preloads() :: list()
  def indexing_preloads do
    user_query = select(User, [u], map(u, [:id, :name]))
    sources_query = select(Source, [s], map(s, [:image_id, :source]))
    alias_tags_query = select(Tag, [t], map(t, [:aliased_tag_id, :name]))

    base_tags_query =
      Tag
      |> select([t], [:category, :id, :name])
      |> preload(aliases: ^alias_tags_query)

    [
      :gallery_interactions,
      sources: sources_query,
      user: user_query,
      favers: user_query,
      downvoters: user_query,
      upvoters: user_query,
      hiders: user_query,
      subscribers: user_query,
      deleter: user_query,
      tags: base_tags_query
    ]
  end

  @doc group: "Search indexing"
  @doc """
  Performs the worker-side search reindex operation for images matching the
  given criteria. PostgreSQL is the source of truth; OpenSearch is updated
  asynchronously by the indexing jobs queued elsewhere in this context.

  ## Parameters
  - column: The database column to filter on (e.g., :id)
  - condition: A list of values to match against the column

  ## Examples

      iex> perform_reindex(:id, [1, 2, 3])
      :ok

  """
  @spec perform_reindex(atom(), [term()]) :: term()
  def perform_reindex(column, condition) do
    Image
    |> preload(^indexing_preloads())
    |> where([i], field(i, ^column) in ^condition)
    |> Search.reindex(Image)
  end
end
