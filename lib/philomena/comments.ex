defmodule Philomena.Comments do
  @moduledoc """
  Image comment reads, writes, moderation, search, and indexing.

  Comment mutations lock their parent image before locking or changing the
  comment. This serializes them with image hides and merges, which can change
  the visibility or ownership of the image's comments.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Multi
  alias Philomena.Attribution.Actor
  alias Philomena.Comments
  alias Philomena.Comments.{Comment, CommentHistory, Query, Visibility}
  alias Philomena.Filters.Filter
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.IndexWorker
  alias Philomena.IntegerId
  alias Philomena.Loader
  alias Philomena.ModerationLogs
  alias Philomena.ModerationLogs.Paths
  alias Philomena.Notifications
  alias Philomena.RateLimiter
  alias Philomena.Repo
  alias Philomena.Reports
  alias Philomena.Tags.Tag
  alias Philomena.UserStatistics
  alias Philomena.Users.User
  alias Philomena.Versions
  alias PhilomenaQuery.Batch
  alias PhilomenaQuery.Search

  @comment_create_window 15
  @image_preloads [:sources, tags: :aliases]
  @preloads [:deleted_by, image: @image_preloads, user: [awards: :badge]]

  defp load_image_comment(%Actor{} = actor, %Image{} = image, comment_id, action, preloads) do
    Comment
    |> where(image_id: ^image.id)
    |> Loader.fetch_and_authorize(actor, action, comment_id, preloads)
  end

  defp load_visible_comment(queryable, %Actor{} = actor, comment_id, preloads) do
    queryable
    |> Visibility.visible_comments(actor)
    |> Loader.fetch(comment_id, preloads)
  end

  defp notify_comment(_repo, %{locked_image: image, comment: comment}) do
    Notifications.broadcast_image_comment(comment.user, image, comment)
  end

  defp broadcast_comment(event, %Comment{} = comment) do
    PhilomenaWeb.Endpoint.broadcast!(
      "firehose",
      event,
      PhilomenaWeb.Api.Json.CommentView.render("show.json", %{comment: comment})
    )

    comment
  end

  defp load_direction(%User{settings: %{comments_newest_first: false}}), do: :asc
  defp load_direction(_user), do: :desc

  defp filter_direction(query, %Comment{} = comment, %User{
         settings: %{comments_newest_first: false}
       }) do
    where(
      query,
      [candidate],
      candidate.created_at < ^comment.created_at or
        (candidate.created_at == ^comment.created_at and candidate.id < ^comment.id)
    )
  end

  defp filter_direction(query, %Comment{} = comment, _user) do
    where(
      query,
      [candidate],
      candidate.created_at > ^comment.created_at or
        (candidate.created_at == ^comment.created_at and candidate.id > ^comment.id)
    )
  end

  defp put_reindex_comment(%Multi{} = multi, step \\ :comment) do
    Multi.on_commit(multi, fn %{^step => comment} -> reindex_comment(comment) end)
  end

  defp put_approval_report(%Multi{} = multi) do
    Multi.merge(multi, fn %{comment: comment} ->
      cond do
        comment.became_unapproved? ->
          Multi.new()
          |> UserStatistics.put_increment(comment.user_id, :comments_count, -1)
          |> Reports.put_create_system_report(
            "Approval",
            "Comment contains external links",
            :comment_id,
            comment.id
          )

        comment.became_approved? ->
          UserStatistics.put_increment(Multi.new(), comment.user_id, :comments_count)

        true ->
          Multi.new()
      end
    end)
  end

  defp put_lock_image(%Multi{} = multi, actor, image_id, action) do
    image_query = where(Image, id: ^image_id)

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
      {:error, _step, :unauthorized, _changes} ->
        {:error, :unauthorized}

      {:error, _step, :not_found, _changes} ->
        {:error, :not_found}
    end
  end

  @doc """
  Builds the blank comment changeset used while assembling an image page.

  This is a cross-context form builder. Authorization of the containing
  image page remains with `Philomena.Images`.

  ## Examples

      iex> new_comment_changeset()
      %Ecto.Changeset{}

  """
  @spec new_comment_changeset() :: Ecto.Changeset.t()
  def new_comment_changeset, do: Comment.changeset(%Comment{})

  @doc """
  Loads a globally addressed comment visible to `actor` in its image thread.

  Hidden comments load so callers can show a placeholder. Destroyed comments,
  comments outside the actor's thread visibility, and missing IDs are
  not-found. A forbidden parent image is unauthorized.

  ## Examples

      iex> show_comment(actor, "1")
      {:ok, %Comment{}}

      iex> show_comment(actor, "not-a-number")
      {:error, :not_found}

  """
  @spec show_comment(Actor.t(), IntegerId.integer_id()) ::
          {:ok, Comment.t()} | {:error, :unauthorized | :not_found}
  def show_comment(%Actor{} = actor, id) do
    with {:ok, comment} <-
           Comment
           |> where(destroyed_content: false)
           |> load_visible_comment(actor, id, @preloads),
         :ok <- authorize(actor, :show, comment.image) do
      {:ok, comment}
    end
  end

  @doc """
  Searches comments visible to `actor`, applying `filter`, `query_string`, and
  `pagination`, newest first.

  Hidden images, hidden or destroyed comments, and approval states are filtered
  independently through the actor's abilities. A signed-in author may see their
  own unapproved comments.

  ## Examples

      iex> query_comments(actor, filter, "created_at.gte:1 week ago", pagination)
      {:ok, %Scrivener.Page{}}

      iex> query_comments(actor, filter, "created_at.gte:not-a-date", pagination)
      {:error, "Cannot parse date."}

  """
  @spec query_comments(
          Actor.t(),
          Filter.t(),
          String.t() | nil,
          Search.pagination_params()
        ) ::
          {:ok, Scrivener.Page.t(Comment.t())} | {:error, String.t()}
  def query_comments(%Actor{} = actor, %Filter{} = filter, query_string, pagination) do
    case Query.compile(query_string, actor: actor) do
      {:ok, query} ->
        results =
          actor
          |> comment_search_definition(filter, query, pagination: pagination)
          |> Search.search_records(preload(Comment, ^@preloads))

        {:ok, results}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @doc """
  Builds an unexecuted comment search definition for `actor`.

  `show_hidden: false` forces public visibility even for privileged actors.

  ## Examples

      iex> comment_search_definition(actor, filter, %{term: %{author_id: 1}})
      %{module: Comment, ...}

  """
  @spec comment_search_definition(Actor.t(), Filter.t(), map() | [map()], keyword()) ::
          Search.search_definition()
  def comment_search_definition(%Actor{} = actor, %Filter{} = filter, body, opts \\ []) do
    pagination = Keyword.get(opts, :pagination, %{})
    allow_privileged? = Keyword.get(opts, :show_hidden, true)

    Search.search_definition(
      Comment,
      %{
        query: %{
          bool: %{
            must: body,
            must_not: Visibility.search_exclusions(actor, filter, allow_privileged?)
          }
        },
        sort: %{created_at: :desc}
      },
      pagination
    )
  end

  @doc """
  Returns a database-paginated page of comments visible beneath `image`.

  Visibility, approval, and destroyed-content filters run before pagination.
  Results use the actor's newest/oldest-first setting.

  ## Examples

      iex> list_image_comments(actor, image, page: 1, page_size: 25)
      %Scrivener.Page{}

  """
  @spec list_image_comments(Actor.t(), Image.t(), Repo.pagination_params()) ::
          Scrivener.Page.t(Comment.t())
  def list_image_comments(%Actor{} = actor, %Image{} = image, pagination) do
    direction = load_direction(actor.user)

    Comment
    |> where(image_id: ^image.id)
    |> Visibility.visible_comments(actor)
    |> order_by([{^direction, :created_at}, {^direction, :id}])
    |> preload(^@preloads)
    |> Repo.paginate(pagination)
  end

  @doc """
  Locates the comment page containing `comment_id` through its parent image,
  on behalf of `actor`.

  Missing, malformed, mismatched, or collection-invisible comments are
  not-found. Returns the loaded image for the caller to reuse.

  ## Examples

      iex> list_comment_page(actor, image_id, comment.id, page_size: 25)
      {:ok, {%Image{}, 3}}

  """
  @spec list_comment_page(
          actor :: Actor.t(),
          image_id :: IntegerId.integer_id(),
          comment_id :: IntegerId.integer_id(),
          pagination :: Repo.pagination_params()
        ) ::
          {:ok, {Image.t(), pos_integer()}} | {:error, :unauthorized | :not_found}
  def list_comment_page(%Actor{} = actor, image_id, comment_id, pagination) do
    with {:ok, image} <- load_image(actor, image_id, :index),
         {:ok, comment} <-
           Comment
           |> where(image_id: ^image.id)
           |> load_visible_comment(actor, comment_id, []) do
      offset =
        Comment
        |> where(image_id: ^image.id)
        |> Visibility.visible_comments(actor)
        |> filter_direction(comment, actor.user)
        |> Repo.aggregate(:count)

      {:ok, {image, div(offset, pagination[:page_size]) + 1}}
    end
  end

  @doc """
  Returns the final visible comment page beneath `image` for `actor`.

  ## Examples

      iex> last_comment_page(actor, image, page_size: 25)
      4

  """
  @spec last_comment_page(Actor.t(), Image.t(), Repo.pagination_params()) :: pos_integer()
  def last_comment_page(%Actor{} = actor, %Image{} = image, pagination) do
    count =
      Comment
      |> where(image_id: ^image.id)
      |> Visibility.visible_comments(actor)
      |> Repo.aggregate(:count)

    max(Integer.ceil_div(count, pagination[:page_size]), 1)
  end

  @doc """
  Loads and authorizes an image for comment actions.

  `action` must be one of `:index`, `:show`, or `:create_comment`.

  Duplicate images are resolved to their target. Missing IDs are
  always not-found.

  ## Examples

      iex> load_image(actor, "1", :index)
      {:ok, %Image{}}

      iex> load_image(actor, "not-a-number", :show)
      {:error, :not_found}

  """
  @spec load_image(Actor.t(), IntegerId.integer_id(), atom()) ::
          {:ok, Image.t()} | {:error, :unauthorized | :not_found}
  def load_image(%Actor{} = actor, image_id, action)
      when action in [:index, :show, :create_comment] do
    case Loader.fetch_and_authorize(Image, actor, action, image_id, @image_preloads) do
      {:ok, %Image{duplicate_id: nil} = image} ->
        {:ok, image}

      {:ok, %Image{duplicate_id: duplicate_id}} ->
        Loader.fetch_and_authorize(Image, actor, action, duplicate_id, @image_preloads)

      error ->
        error
    end
  end

  @doc """
  Creates a comment through its parent image, on behalf of `actor`.

  Write access, image commenting permission, the Images-owned forced-filter
  prerequisite, and the 15-second creation limit are checked before insertion.
  The transaction updates the image count, notification, and subscription state.
  Indexing, statistics/reporting, rate tracking, and the firehose broadcast run
  after commit. The image is returned for the caller to reuse.

  ## Examples

      iex> create_comment(actor, image_id, %{"body" => "Hi"})
      {:ok, {%Image{}, %Comment{}}}

      iex> create_comment(actor, image_id, %{"body" => ""})
      {:error, {%Image{}, %Ecto.Changeset{}}}

      iex> create_comment(banned_actor, image_id, %{"body" => "Hi"})
      {:error, :ban}

  """
  @spec create_comment(Actor.t(), IntegerId.integer_id(), map()) ::
          {:ok, Comment.t()}
          | {:error, {Image.t(), Ecto.Changeset.t()}}
          | {:error, :ban | :unauthorized | :forced_filter | :rate_limited}
  def create_comment(%Actor{user: creator} = actor, image_id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image(actor, image_id, :create_comment),
         :ok <- Images.verify_forced_filter_access(actor, image) do
      comment_changeset =
        image
        |> Ecto.build_assoc(:comments)
        |> Comment.creation_changeset(attrs, actor)

      Multi.new()
      |> Multi.reserve_action(
        fn -> RateLimiter.record_action(actor, :comment_create, @comment_create_window) end,
        fn -> RateLimiter.rollback_action(actor, :comment_create) end
      )
      |> put_lock_image(actor, image.id, :create_comment)
      |> Multi.insert(:comment, comment_changeset)
      |> Images.put_image_counter_delta(:update_image, image.id, :comments_count, 1)
      |> Multi.run(:notification, &notify_comment/2)
      |> Images.maybe_subscribe_on(:locked_image, creator, :watch_on_reply)
      |> Images.put_reindex_image(:locked_image)
      |> UserStatistics.put_increment(creator, :comments_count)
      |> put_approval_report()
      |> put_reindex_comment()
      |> Multi.transact()
      |> case do
        {:ok, %{comment: %Comment{} = comment}} ->
          broadcast_comment("comment:create", comment)
          {:ok, comment}

        {:error, :action_reservation, :rate_limited, _changes} ->
          {:error, :rate_limited}

        {:error, :comment, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, {image, changeset}}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Loads a comment shown in its parent image's thread for `actor`.

  Hidden comments load so callers can show a placeholder. Comments outside the
  actor's thread visibility are not-found. The loaded image is returned for the
  caller to reuse.

  ## Examples

      iex> show_comment(actor, "1", "2")
      {:ok, {%Image{}, %Comment{}}}

      iex> show_comment(actor, "1", "not-a-number")
      {:error, :not_found}

  """
  @spec show_comment(
          actor :: Actor.t(),
          image_id :: IntegerId.integer_id(),
          comment_id :: IntegerId.integer_id()
        ) ::
          {:ok, {Image.t(), Comment.t()}} | {:error, :unauthorized | :not_found}
  def show_comment(%Actor{} = actor, image_id, comment_id) do
    with {:ok, image} <- load_image(actor, image_id, :show),
         {:ok, comment} <-
           Comment
           |> where(image_id: ^image.id)
           |> load_visible_comment(actor, comment_id, @preloads) do
      {:ok, {image, comment}}
    end
  end

  @doc """
  Loads an editable comment and changeset through its parent image.

  A ban is checked before image authorization, forced-filter enforcement, and
  comment authorization; a missing fingerprint is left to `update_comment/4`.

  ## Examples

      iex> edit_comment(actor, "1", "2")
      {:ok, %Ecto.Changeset{data: %Comment{}}}

      iex> edit_comment(banned_actor, "1", "2")
      {:error, :ban}

  """
  @spec edit_comment(
          actor :: Actor.t(),
          image_id :: IntegerId.integer_id(),
          comment_id :: IntegerId.integer_id()
        ) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :unauthorized | :not_found | :forced_filter}
  def edit_comment(%Actor{} = actor, image_id, comment_id) do
    with :ok <- verify_not_banned(actor),
         {:ok, image} <- load_image(actor, image_id, :create_comment),
         :ok <- Images.verify_forced_filter_access(actor, image),
         {:ok, comment} <- load_image_comment(actor, image, comment_id, :edit, @preloads) do
      {:ok, Comment.changeset(comment)}
    end
  end

  @doc """
  Updates a parent-scoped comment on behalf of `actor`.

  Write access is checked before image authorization, forced-filter enforcement,
  and comment authorization. A successful transaction records the prior version
  Reporting, indexing, and the firehose broadcast run after commit. Validation
  returns the changeset preserving the loaded comment and image. On success,
  the image is returned for the caller to reuse.

  ## Examples

      iex> update_comment(actor, image, "1", %{"body" => "Edited"})
      {:ok, {%Image{}, %Comment{}}}

      iex> update_comment(actor, image, "1", %{"body" => ""})
      {:error, %Ecto.Changeset{data: %Comment{}}}

  """
  @spec update_comment(
          actor :: Actor.t(),
          image_id :: IntegerId.integer_id(),
          comment_id :: IntegerId.integer_id(),
          attrs :: map() | nil
        ) ::
          {:ok, {Image.t(), Comment.t()}}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found | :forced_filter}
  def update_comment(%Actor{} = actor, image_id, comment_id, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image(actor, image_id, :create_comment),
         :ok <- Images.verify_forced_filter_access(actor, image),
         {:ok, comment} <- load_image_comment(actor, image, comment_id, :update, @preloads) do
      now = DateTime.utc_now(:second)
      comment_changeset = Comment.changeset(comment, attrs, now)

      comment_query =
        Comment
        |> where(id: ^comment.id)
        |> preload(:user)

      Multi.new()
      |> put_lock_image(actor, image.id, :create_comment)
      |> Multi.lock_one(:original_comment, comment_query)
      |> Multi.update(:comment, comment_changeset)
      |> Versions.record_edit(:version, :original_comment, :comment, actor)
      |> put_approval_report()
      |> put_reindex_comment()
      |> Multi.transact()
      |> case do
        {:ok, %{comment: %Comment{} = comment}} ->
          broadcast_comment("comment:update", comment)

          {:ok, {image, comment}}

        {:error, :comment, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Loads a visible comment's edit history through its parent image.

  Parent and child IDs are parsed and scoped before authorization. The returned
  `CommentHistory` carries the latest 25 versions with authors and diffs.

  ## Examples

      iex> list_comment_history(actor, "1", "2")
      {:ok, %CommentHistory{}}

      iex> list_comment_history(actor, "1", "not-a-number")
      {:error, :not_found}

  """
  @spec list_comment_history(Actor.t(), IntegerId.integer_id(), IntegerId.integer_id()) ::
          {:ok, CommentHistory.t()} | {:error, :unauthorized | :not_found}
  def list_comment_history(%Actor{} = actor, image_id, comment_id) do
    with {:ok, image} <- load_image(actor, image_id, :show),
         {:ok, comment} <- load_image_comment(actor, image, comment_id, :show, @preloads) do
      {:ok,
       %CommentHistory{
         image: image,
         comment: comment,
         versions: Versions.for_comment(comment)
       }}
    end
  end

  @doc """
  Loads a comment as a report target through its parent image.

  Both resources are authorized for `:show`. Malformed, missing, and mismatched
  IDs are not-found. Reports owns the write prerequisite and form changeset.

  ## Examples

      iex> load_report_target(actor, "1", "2")
      {:ok, %Comment{}}

  """
  @spec load_report_target(Actor.t(), IntegerId.integer_id(), IntegerId.integer_id()) ::
          {:ok, Comment.t()} | {:error, :unauthorized | :not_found}
  def load_report_target(%Actor{} = actor, image_id, comment_id) do
    with {:ok, image} <- load_image(actor, image_id, :show) do
      load_image_comment(actor, image, comment_id, :show, @preloads)
    end
  end

  @doc """
  Hides a comment scoped through its parent image.

  The comment update, report closure, and moderation log commit atomically.

  ## Examples

      iex> create_comment_hide(moderator, "1", "2", %{"deletion_reason" => "Spam"})
      {:ok, %Comment{}}

  """
  @spec create_comment_hide(Actor.t(), IntegerId.integer_id(), IntegerId.integer_id(), map()) ::
          {:ok, Comment.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found}
  def create_comment_hide(%Actor{user: user} = actor, image_id, comment_id, params) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image(actor, image_id, :show),
         {:ok, comment} <- load_image_comment(actor, image, comment_id, :hide, @preloads) do
      changeset = Comment.hide_changeset(comment, params, user)
      reason = Ecto.Changeset.get_field(changeset, :deletion_reason)

      Multi.new()
      |> put_lock_image(actor, image.id, :show)
      |> Multi.update(:comment, changeset)
      |> Reports.put_close_reports(:reports, user, comment_id: comment.id)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        "Image.Comment.Hide:create",
        Paths.image_comment_path(comment.image_id, comment.id),
        "Deleted comment on image #{comment.image_id} (#{reason})"
      )
      |> put_reindex_comment()
      |> Multi.transact()
      |> case do
        {:ok, %{comment: %Comment{} = comment}} ->
          {:ok, comment}

        {:error, :comment, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Restores a comment through its parent image.

  ## Examples

      iex> delete_comment_hide(moderator, "1", "2")
      {:ok, %Comment{}}

  """
  @spec delete_comment_hide(Actor.t(), IntegerId.integer_id(), IntegerId.integer_id()) ::
          {:ok, Comment.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found}
  def delete_comment_hide(%Actor{} = actor, image_id, comment_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image(actor, image_id, :show),
         {:ok, comment} <- load_image_comment(actor, image, comment_id, :hide, @preloads) do
      changeset = Comment.unhide_changeset(comment)

      Multi.new()
      |> put_lock_image(actor, image.id, :show)
      |> Multi.update(:comment, changeset)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        "Image.Comment.Hide:delete",
        Paths.image_comment_path(comment.image_id, comment.id),
        "Restored comment on image #{comment.image_id}"
      )
      |> put_reindex_comment()
      |> Multi.transact()
      |> case do
        {:ok, %{comment: %Comment{} = comment}} ->
          {:ok, comment}

        {:error, :comment, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Destroys a comment's content through its parent image.

  Authorization uses the distinct `:delete` action. Content removal, image
  counters, and the moderation log commit together.

  ## Examples

      iex> create_comment_delete(moderator, "1", "2")
      {:ok, %Comment{}}

  """
  @spec create_comment_delete(Actor.t(), IntegerId.integer_id(), IntegerId.integer_id()) ::
          {:ok, Comment.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found}
  def create_comment_delete(%Actor{} = actor, image_id, comment_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image(actor, image_id, :show),
         {:ok, comment} <- load_image_comment(actor, image, comment_id, :delete, @preloads) do
      comment_query = from(c in Comment, where: c.id == ^comment.id)

      Multi.new()
      |> put_lock_image(actor, image.id, :show)
      |> Multi.lock_one(:locked_comment, comment_query)
      |> Multi.update(:comment, fn %{locked_comment: comment} ->
        Comment.destroy_changeset(comment)
      end)
      |> Images.put_image_counter_delta(:update_image, image.id, :comments_count, -1)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        "Image.Comment.Delete:create",
        Paths.image_comment_path(comment.image_id, comment.id),
        "Destroyed comment on image #{comment.image_id}"
      )
      |> UserStatistics.put_increment(
        fn %{comment: comment} ->
          if comment.approved, do: comment.user_id
        end,
        :comments_count,
        -1
      )
      |> Images.put_reindex_image(:locked_image)
      |> put_reindex_comment()
      |> Multi.transact()
      |> case do
        {:ok, %{comment: %Comment{} = comment}} ->
          {:ok, comment}

        {:error, :comment, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Approves a comment through its parent image.

  Approval, report closure, author statistics, and the moderation log commit
  together.

  ## Examples

      iex> create_comment_approve(moderator, "1", "2")
      {:ok, %Comment{}}

  """
  @spec create_comment_approve(Actor.t(), IntegerId.integer_id(), IntegerId.integer_id()) ::
          {:ok, Comment.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found}
  def create_comment_approve(%Actor{user: user} = actor, image_id, comment_id) do
    with :ok <- verify_write_access(actor),
         {:ok, image} <- load_image(actor, image_id, :show),
         {:ok, comment} <- load_image_comment(actor, image, comment_id, :approve, @preloads) do
      comment_query = from(c in Comment, where: c.id == ^comment.id)

      Multi.new()
      |> put_lock_image(actor, image.id, :show)
      |> Multi.lock_one(:locked_comment, comment_query)
      |> Multi.update(:comment, fn %{locked_comment: comment} ->
        Comment.approve_changeset(comment)
      end)
      |> Reports.put_close_reports(:reports, user, comment_id: comment.id)
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        "Image.Comment.Approve:create",
        Paths.image_comment_path(comment.image_id, comment.id),
        "Approved comment on image #{comment.image_id}"
      )
      |> UserStatistics.put_increment(comment.user_id, :comments_count)
      |> put_reindex_comment()
      |> Multi.transact()
      |> case do
        {:ok, %{comment: %Comment{} = comment}} ->
          {:ok, comment}

        {:error, :comment, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Moves comments from one image to another inside `multi` and adds the moved
  comments that are not destroyed to the target image's comment count.
  """
  @spec put_migrate_image_comments(Multi.t(), Image.t(), Image.t()) :: Multi.t()
  def put_migrate_image_comments(%Multi{} = multi, %Image{} = source, %Image{} = target) do
    query =
      Comment
      |> where(image_id: ^source.id)
      |> select([c], c.destroyed_content)
      |> update(set: [image_id: ^target.id])

    multi
    |> Multi.update_all(:migrated_comments, query, [])
    |> Images.put_image_counter_delta(
      :migrated_comment_count,
      target.id,
      :comments_count,
      fn %{migrated_comments: {_count, destroyed}} -> Enum.count(destroyed, &(not &1)) end
    )
  end

  @doc """
  Replaces attribution data on a user's comments in batches.
  """
  @spec wipe_user_attribution!(integer(), term(), String.t()) :: :ok
  def wipe_user_attribution!(user_id, ip, fingerprint) do
    Comment
    |> where(user_id: ^user_id)
    |> Batch.query_batches()
    |> Enum.each(&Repo.update_all(&1, set: [ip: ip, fingerprint: fingerprint]))

    :ok
  end

  @doc """
  Updates indexed comment author names after a user rename.

  ## Examples

      iex> user_name_reindex("old_username", "new_username")
      :ok

  """
  @spec user_name_reindex(String.t(), String.t()) :: term()
  def user_name_reindex(old_name, new_name) do
    data = Comments.SearchIndex.user_name_update_by_query(old_name, new_name)
    Search.update_by_query(Comment, data.query, data.set_replacements, data.replacements)
  end

  @doc """
  Queues one comment for search indexing and returns it unchanged.

  ## Examples

      iex> reindex_comment(comment)
      %Comment{}

  """
  @spec reindex_comment(Comment.t()) :: Comment.t()
  def reindex_comment(%Comment{} = comment) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Comments", "id", [comment.id]])
    comment
  end

  @doc """
  Queues every comment on `image` for indexing and returns the image unchanged.

  ## Examples

      iex> reindex_comments_on_image(image)
      %Image{}

  """
  @spec reindex_comments_on_image(Image.t()) :: Image.t()
  def reindex_comments_on_image(%Image{} = image) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Comments", "image_id", [image.id]])
    image
  end

  @doc """
  Queues comments on the given image IDs for reindexing and returns the list unchanged.

  ## Examples

      iex> reindex_comments_on_images([1, 2, 3])
      [1, 2, 3]

  """
  @spec reindex_comments_on_images([integer()]) :: [integer()]
  def reindex_comments_on_images(image_ids) when is_list(image_ids) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Comments", "image_id", image_ids])
    image_ids
  end

  @doc """
  Returns the association queries required to serialize comment search records.

  ## Examples

      iex> indexing_preloads()
      [user: user_query, image: image_query, deleted_by: user_query]

  """
  @spec indexing_preloads() :: list()
  def indexing_preloads do
    user_query = select(User, [user], map(user, [:id, :name]))
    tag_query = select(Tag, [tag], map(tag, [:id, :name]))

    image_query =
      Image
      |> select([image], struct(image, [:approved, :hidden_from_users, :id]))
      |> preload(tags: ^tag_query)

    [user: user_query, image: image_query, deleted_by: user_query]
  end

  @doc """
  Reindexes comments selected by a trusted worker column and values.

  ## Examples

      iex> perform_reindex(:id, [1, 2, 3])
      :ok

  """
  @spec perform_reindex(atom(), [term()]) :: term()
  def perform_reindex(column, condition) when is_atom(column) and is_list(condition) do
    Comment
    |> preload(^indexing_preloads())
    |> where([comment], field(comment, ^column) in ^condition)
    |> Search.reindex(Comment)
  end
end
