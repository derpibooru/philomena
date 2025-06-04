defmodule Philomena.Tags do
  @moduledoc """
  The Tags context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias PhilomenaQuery.Search
  alias Philomena.IndexWorker
  alias Philomena.TagAliasWorker
  alias Philomena.TagUnaliasWorker
  alias Philomena.TagReindexWorker
  alias Philomena.TagDeleteWorker
  alias Philomena.Tags.Tag
  alias Philomena.Tags.Uploader
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.Users.User
  alias Philomena.Filters
  alias Philomena.Filters.Filter
  alias Philomena.Images.Tagging
  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.Channels.Channel

  # There is a really delicate nuance that must be known to avoid deadlocks in
  # vectorized mutation queries such as `INSERT ON CONFLICT UPDATE`, `UPDATE`,
  # `DELETE`, `SELECT FOR [NO KEY] UPDATE` that touch multiple records. Note that
  # `INSERT ON CONFLICT DO NOTHING` doesn't lock the conflicting records, so this
  # nuance doesn't apply in that case (https://dba.stackexchange.com/questions/322912/will-insert-on-conflict-do-nothing-lock-the-row-in-case-of-conflict)
  #
  # If a vectorized mutation is run without a consistent locking order of the records,
  # it can end up with a deadlock where one transaction locks a set of records
  # that overlap with the other transaction while the other transaction locks
  # the other set that overlaps with the first transaction. Thus, both transactions
  # wait for each other to release the locks on records they locked resulting in
  # a deadlock.
  #
  # For raw `UPDATE/DELETE ... WHERE ... IN (...)` queries, the items inside `IN (...)`
  # don't influence the order of locking. These queries also don't have an `ORDER BY`
  # clause. Thus, this function returns a `SELECT [lock_type]` query that establishes a
  # consistent order of records by primary keys that must be used with all vectorized
  # mutation queries to avoid deadlocks. This query can be used as a subquery in
  # the `WHERE` clause for the vectorized mutation.
  #
  # If no locking order is set, the deadlock can appear randomly and its probability
  # increases with the amount of items in the vectorized mutation query and with
  # the number of overlapping records in concurrent transactions.
  #
  # This phenomena was discovered when @MareStare was trying to parallelize
  # the image creation process for seeding the images during development, where
  # tons of image uploads are issued in parallel with many overlapping tags
  # (https://github.com/philomena-dev/philomena/pull/481).
  #
  # Big thanks to this StackOverflow post for explanations:
  # https://stackoverflow.com/questions/27262900/postgres-update-and-lock-ordering/27263824#27263824
  defmacro vectorized_mutation_lock(lock_type, tag_ids) do
    quote do
      Tag
      |> select([t], t.id)
      |> lock(unquote(lock_type))
      |> where([t], t.id in ^unquote(tag_ids))
      |> order_by([t], t.id)
    end
  end

  @doc """
  Gets existing tags or creates new ones from a tag list string.

  Takes a string of comma-separated tag names, parses it into individual tags,
  and either retrieves existing tags or creates new ones for tags that don't exist.
  Also handles tag aliases by returning the aliased tag instead of the alias.

  ## Examples

      iex> get_or_create_tags("safe, cute, pony")
      [%Tag{name: "safe"}, %Tag{name: "cute"}, %Tag{name: "pony"}]

  """
  @spec get_or_create_tags(String.t()) :: list()
  def get_or_create_tags(tag_list) do
    case Tag.parse_tag_list(tag_list) do
      [] -> []
      tag_names -> get_or_create_non_empty_tags_list(tag_names)
    end
  end

  @spec get_or_create_non_empty_tags_list(list(String.t())) :: list()
  defp get_or_create_non_empty_tags_list(tag_names) do
    tags =
      tag_names
      |> Enum.map(fn tag_name ->
        %Tag{}
        |> Tag.creation_changeset(%{name: tag_name})
        |> Ecto.Changeset.apply_changes()
        |> Map.take([
          :slug,
          :name,
          :category,
          :images_count,
          :description,
          :short_description,
          :namespace,
          :name_in_namespace,
          :image,
          :image_format,
          :image_mime_type,
          :mod_notes
        ])
        |> Map.merge(%{
          created_at: {:placeholder, :timestamp},
          updated_at: {:placeholder, :timestamp}
        })
      end)

    %{new_tags: {_rows_affected, new_tags}, all_tags: all_tags} =
      Multi.new()
      |> Multi.insert_all(
        :new_tags,
        Tag,
        tags,
        placeholders: %{timestamp: DateTime.utc_now(:second)},
        on_conflict: :nothing,
        returning: [:id]
      )
      |> Multi.all(
        :all_tags,
        Tag
        |> where([t], t.name in ^tag_names)
        |> preload([:implied_tags, aliased_tag: :implied_tags])
      )
      |> Repo.transaction()
      |> case do
        {:ok, ok} ->
          ok

        result ->
          raise "get_or_create_tags failed: #{inspect(result)}\ntag_names: #{inspect(tag_names)}"
      end

    new_tags
    |> reindex_tags()

    all_tags
    |> Enum.map(&(&1.aliased_tag || &1))
    |> Enum.uniq_by(& &1.id)
  end

  @doc """
  Gets a single tag.

  Raises `Ecto.NoResultsError` if the Tag does not exist.

  ## Examples

      iex> get_tag!(123)
      %Tag{}

      iex> get_tag!(456)
      ** (Ecto.NoResultsError)

  """
  def get_tag!(id), do: Repo.get!(Tag, id)

  @doc """
  Gets a single tag.

  Returns nil if the Tag does not exist.

  ## Examples

      iex> get_tag_by_name("safe")
      %Tag{}

      iex> get_tag_by_name("nonexistent")
      nil

  """
  def get_tag_by_name(name), do: Repo.get_by(Tag, name: name)

  @doc """
  Gets a single tag by its name, or the tag it is aliased to, if it is aliased.

  Returns nil if the tag does not exist.

  ## Examples

      iex> get_tag_or_alias_by_name("safe")
      %Tag{}

      iex> get_tag_or_alias_by_name("nonexistent")
      nil

  """
  def get_tag_or_alias_by_name(name) do
    Tag
    |> where(name: ^name)
    |> preload(:aliased_tag)
    |> Repo.one()
    |> case do
      nil -> nil
      tag -> tag.aliased_tag || tag
    end
  end

  @doc """
  Creates a tag.

  ## Examples

      iex> create_tag(%{field: value})
      {:ok, %Tag{}}

      iex> create_tag(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_tag(attrs \\ %{}) do
    %Tag{}
    |> Tag.creation_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tag.

  ## Examples

      iex> update_tag(tag, %{field: new_value})
      {:ok, %Tag{}}

      iex> update_tag(tag, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_tag(%Tag{} = tag, attrs) do
    tag_input = Tag.parse_tag_list(attrs["implied_tag_list"])

    implied_tags =
      Tag
      |> where([t], t.name in ^tag_input)
      |> Repo.all()

    tag
    |> Tag.changeset(attrs, implied_tags)
    |> Repo.update()
    |> reindex_after_update(tag)
  end

  defp reindex_after_update(result, old_tag) do
    case result do
      {:ok, tag} ->
        if tag.category != old_tag.category do
          reindex_tag_images(tag)
        end

        reindex_tag(tag)
        {:ok, tag}

      error ->
        error
    end
  end

  @doc """
  Updates a tag's associated image.

  Takes a tag and image upload attributes, analyzes the upload,
  persists it, and removes the old tag image if successful.

  ## Examples

      iex> update_tag_image(tag, %{"image" => upload})
      {:ok, %Tag{}}

  """
  def update_tag_image(%Tag{} = tag, attrs) do
    tag
    |> Uploader.analyze_upload(attrs)
    |> Repo.update()
    |> case do
      {:ok, tag} ->
        Uploader.persist_upload(tag)
        Uploader.unpersist_old_upload(tag)

        {:ok, tag}

      error ->
        error
    end
  end

  @doc """
  Removes a tag's associated image.

  Removes the image from the tag and deletes the persisted file.

  ## Examples

      iex> remove_tag_image(tag)
      {:ok, %Tag{}}

  """
  def remove_tag_image(%Tag{} = tag) do
    tag
    |> Tag.remove_image_changeset()
    |> Repo.update()
    |> case do
      {:ok, tag} ->
        Uploader.unpersist_old_upload(tag)

        {:ok, tag}

      error ->
        error
    end
  end

  @doc """
  Deletes a Tag.

  ## Examples

      iex> delete_tag(tag)
      {:ok, %Tag{}}

      iex> delete_tag(tag)
      {:error, %Ecto.Changeset{}}

  """
  def delete_tag(%Tag{} = tag) do
    Exq.enqueue(Exq, "indexing", TagDeleteWorker, [tag.id])

    {:ok, tag}
  end

  @doc """
  Performs the actual deletion of a tag.

  Removes the tag from the database, deletes its search index,
  and reindexes all images that were tagged with it.

  ## Examples

      iex> perform_delete(123)
      :ok

  """
  def perform_delete(tag_id) do
    tag = get_tag!(tag_id)

    image_ids =
      Image
      |> join(:inner, [i], _ in assoc(i, :tags))
      |> where([_i, t], t.id == ^tag.id)
      |> select([i, _t], i.id)
      |> Repo.all()

    {:ok, tag} = Repo.delete(tag)

    Search.delete_document(tag.id, Tag)

    Image
    |> where([i], i.id in ^image_ids)
    |> preload(^Images.indexing_preloads())
    |> Search.reindex(Image)
  end

  @doc """
  Creates an alias from one tag to another.

  Takes a source tag and target tag name, creating an alias relationship
  where the source tag becomes an alias of the target tag. Once the alias
  is created, a job is queued to finish processing the alias.

  ## Examples

      iex> alias_tag(source_tag, %{"target_tag" => "destination"})
      {:ok, %Tag{}}

  """
  def alias_tag(%Tag{} = tag, attrs) do
    target_tag = Repo.get_by(Tag, name: String.downcase(attrs["target_tag"]))

    tag
    |> Repo.preload(:aliased_tag)
    |> Tag.alias_changeset(target_tag)
    |> Repo.update()
    |> case do
      {:ok, tag} ->
        Exq.enqueue(Exq, "indexing", TagAliasWorker, [tag.id, target_tag.id])

        {:ok, tag}

      error ->
        error
    end
  end

  @doc """
  Performs the actual tag aliasing operation.

  Transfers all associations from the source tag to the target tag,
  including image taggings, filters, user watches, and other relationships.
  Updates counters and reindexes affected records.

  ## Examples

      iex> perform_alias(123, 456)
      :ok

  """
  def perform_alias(tag_id, target_tag_id) do
    tag = get_tag!(tag_id)
    target_tag = get_tag!(target_tag_id)

    filters_hidden =
      where(Filter, [f], fragment("? @> ARRAY[?]::integer[]", f.hidden_tag_ids, ^tag.id))

    filters_spoilered =
      where(Filter, [f], fragment("? @> ARRAY[?]::integer[]", f.spoilered_tag_ids, ^tag.id))

    users_watching =
      where(User, [u], fragment("? @> ARRAY[?]::integer[]", u.watched_tag_ids, ^tag.id))

    array_replace(filters_hidden, :hidden_tag_ids, tag.id, target_tag.id)
    array_replace(filters_spoilered, :spoilered_tag_ids, tag.id, target_tag.id)
    array_replace(users_watching, :watched_tag_ids, tag.id, target_tag.id)

    # Create taggings with the new tag ID on images where the old tag ID is used.
    retag_query =
      from i in Image,
        inner_join: it in Tagging,
        on: it.image_id == i.id,
        select: %{image_id: i.id, tag_id: ^target_tag.id},
        where: it.tag_id == ^tag.id

    Repo.insert_all(Tagging, retag_query, on_conflict: :nothing)

    # Delete taggings on the source tag
    Tagging
    |> where(tag_id: ^tag.id)
    |> Repo.delete_all()

    # Update other associations
    ArtistLink
    |> where(tag_id: ^tag.id)
    |> Repo.update_all(set: [tag_id: target_tag.id])

    DnpEntry
    |> where(tag_id: ^tag.id)
    |> Repo.update_all(set: [tag_id: target_tag.id])

    Channel
    |> where(associated_artist_tag_id: ^tag.id)
    |> Repo.update_all(set: [associated_artist_tag_id: target_tag.id])

    # Update counter
    Tag
    |> where(id: ^tag.id)
    |> Repo.update_all(
      set: [images_count: 0, aliased_tag_id: target_tag.id, updated_at: DateTime.utc_now()]
    )

    # Finally, reindex
    reindex_tag_images(target_tag)
    reindex_tags([tag, target_tag])

    :ok
  end

  @doc """
  Enqueues reindexing of all images associated with a tag.

  ## Examples

      iex> reindex_tag_images(tag)
      {:ok, %Tag{}}

  """
  def reindex_tag_images(%Tag{} = tag) do
    Exq.enqueue(Exq, "indexing", TagReindexWorker, [tag.id])

    {:ok, tag}
  end

  @doc """
  Performs reindexing of all images associated with a tag.

  Updates the tag's image count to reflect the current number of non-hidden images,
  then reindexes all associated images and filters that reference this tag.

  ## Examples

      iex> perform_reindex_images(123)

  """
  def perform_reindex_images(tag_id) do
    tag = get_tag!(tag_id)

    # First recount the tag
    image_count =
      Image
      |> join(:inner, [i], _ in assoc(i, :tags))
      |> where([i, t], i.hidden_from_users == false and t.id == ^tag.id)
      |> Repo.aggregate(:count, :id)

    Tag
    |> where(id: ^tag.id)
    |> Repo.update_all(set: [images_count: image_count])

    # Then reindex
    Image
    |> join(:inner, [i], _ in assoc(i, :tags))
    |> where([_i, t], t.id == ^tag.id)
    |> preload(^Images.indexing_preloads())
    |> Search.reindex(Image)

    Filter
    |> where([f], fragment("? @> ARRAY[?]::integer[]", f.hidden_tag_ids, ^tag.id))
    |> or_where([f], fragment("? @> ARRAY[?]::integer[]", f.spoilered_tag_ids, ^tag.id))
    |> preload(^Filters.indexing_preloads())
    |> Search.reindex(Filter)
  end

  @doc """
  Enqueues removal of a tag alias.

  ## Examples

      iex> unalias_tag(tag)
      {:ok, %Tag{}}

  """
  def unalias_tag(%Tag{} = tag) do
    Exq.enqueue(Exq, "indexing", TagUnaliasWorker, [tag.id])

    {:ok, tag}
  end

  @doc """
  Performs removal of a tag alias.

  Removes the alias relationship between two tags and reindexes
  the images of the formerly aliased tag.

  ## Examples

      iex> perform_unalias(123)
      {:ok, %Tag{}}
  """
  def perform_unalias(tag_id) do
    tag = get_tag!(tag_id)
    former_alias = Repo.preload(tag, :aliased_tag).aliased_tag

    tag
    |> Tag.unalias_changeset()
    |> Repo.update()
    |> case do
      {:ok, _} = result ->
        reindex_tag_images(former_alias)
        reindex_tags([tag, former_alias])

        result

      result ->
        result
    end
  end

  defp array_replace(queryable, column, old_value, new_value) do
    queryable
    |> update(
      [q],
      set: [
        {
          ^column,
          fragment("array_replace(?, ?, ?)", field(q, ^column), ^old_value, ^new_value)
        }
      ]
    )
    |> Repo.update_all([])
  end

  @doc """
  Copies tags from one image to another.

  Creates new taggings on the target image for all tags present on the source image,
  updates tag counters, and returns the list of copied tags.

  ## Examples

      iex> copy_tags(source_image, target_image)
      [%Tag{}, ...]

  """
  def copy_tags(source, target) do
    # Ecto bug:
    # ** (DBConnection.EncodeError) Postgrex expected a binary, got 5.
    #
    # what I would like to do:
    #   |> select([t], %{image_id: ^target.id, tag_id: t.tag_id})
    #
    # what I have to do instead:

    taggings =
      Tagging
      |> where(image_id: ^source.id)
      |> select([t], %{image_id: ^to_string(target.id), tag_id: t.tag_id})
      |> Repo.all()
      |> Enum.map(&%{&1 | image_id: String.to_integer(&1.image_id)})

    {:ok, tag_ids} =
      Repo.transaction(fn ->
        {_count, taggings} =
          Repo.insert_all(Tagging, taggings, on_conflict: :nothing, returning: [:tag_id])

        tag_ids = Enum.map(taggings, & &1.tag_id)

        update_image_counts(Repo, 1, tag_ids)

        tag_ids
      end)

    Tag
    |> where([t], t.id in ^tag_ids)
    |> Repo.all()
  end

  @doc """
  Accepts IDs of tags and increments their `images_count` by 1.
  """
  @spec update_image_counts(term(), integer(), [integer()]) :: integer()
  def update_image_counts(repo, diff, tag_ids)

  def update_image_counts(_repo, _diff, []), do: 0

  def update_image_counts(repo, diff, tag_ids) do
    locked_tags = vectorized_mutation_lock("FOR NO KEY UPDATE", tag_ids)

    {rows_affected, _} =
      Tag
      |> where([t], t.id in subquery(locked_tags))
      |> repo.update_all(inc: [images_count: diff])

    rows_affected
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tag changes.

  ## Examples

      iex> change_tag(tag)
      %Ecto.Changeset{source: %Tag{}}

  """
  def change_tag(%Tag{} = tag) do
    Tag.changeset(tag, %{})
  end

  @doc """
  Queues a single tag for search index updates.
  Returns the tag struct unchanged, for use in a pipeline.

  ## Examples

      iex> reindex_tag(tag)
      %Tag{}

  """
  def reindex_tag(%Tag{} = tag) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Tags", "id", [tag.id]])

    tag
  end

  @doc """
  Queues a list of tags for search index updates.
  Returns the list of tags unchanged, for use in a pipeline.

  ## Examples

      iex> reindex_tags([%Tag{}, %Tag{}, ...])
      [%Tag{}, %Tag{}, ...]

  """
  def reindex_tags(tags) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Tags", "id", Enum.map(tags, & &1.id)])

    tags
  end

  @doc """
  Returns the list of associations to preload for tag indexing.

  ## Examples

      iex> indexing_preloads()
      [:aliased_tag, :aliases, :implied_tags, :implied_by_tags]

  """
  def indexing_preloads do
    [:aliased_tag, :aliases, :implied_tags, :implied_by_tags]
  end

  @doc """
  Performs reindexing of tags based on a column condition.

  Takes a column name and a list of values to match against that column,
  then reindexes all matching tags.

  ## Examples

      iex> perform_reindex(:id, [1, 2, 3])
      {:ok, []}

      iex> perform_reindex(:name, ["safe", "suggestive"])
      {:ok, []}

  """
  def perform_reindex(column, condition) do
    Tag
    |> preload(^indexing_preloads())
    |> where([t], field(t, ^column) in ^condition)
    |> Search.reindex(Tag)
  end

  alias Philomena.Tags.Implication

  @doc """
  Returns the list of tags_implied_tags.

  ## Examples

      iex> list_tags_implied_tags()
      [%Implication{}, ...]

  """
  def list_tags_implied_tags do
    Repo.all(Implication)
  end

  @doc """
  Gets a single implication.

  Raises `Ecto.NoResultsError` if the Implication does not exist.

  ## Examples

      iex> get_implication!(123)
      %Implication{}

      iex> get_implication!(456)
      ** (Ecto.NoResultsError)

  """
  def get_implication!(id), do: Repo.get!(Implication, id)

  @doc """
  Creates a implication.

  ## Examples

      iex> create_implication(%{field: value})
      {:ok, %Implication{}}

      iex> create_implication(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_implication(attrs \\ %{}) do
    %Implication{}
    |> Implication.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a implication.

  ## Examples

      iex> update_implication(implication, %{field: new_value})
      {:ok, %Implication{}}

      iex> update_implication(implication, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_implication(%Implication{} = implication, attrs) do
    implication
    |> Implication.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Implication.

  ## Examples

      iex> delete_implication(implication)
      {:ok, %Implication{}}

      iex> delete_implication(implication)
      {:error, %Ecto.Changeset{}}

  """
  def delete_implication(%Implication{} = implication) do
    Repo.delete(implication)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking implication changes.

  ## Examples

      iex> change_implication(implication)
      %Ecto.Changeset{source: %Implication{}}

  """
  def change_implication(%Implication{} = implication) do
    Implication.changeset(implication, %{})
  end
end
