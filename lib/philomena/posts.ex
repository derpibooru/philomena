defmodule Philomena.Posts do
  @moduledoc """
  Forum post reads, writes, moderation, and search indexing.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  import Philomena.Forums.TransactionWorkflow

  alias Philomena.Multi
  alias Philomena.Repo

  alias PhilomenaQuery.Search
  alias Philomena.Topics.Topic
  alias Philomena.Topics
  alias Philomena.Loader
  alias Philomena.ModerationLogs
  alias Philomena.ModerationLogs.Paths
  alias Philomena.UserStatistics
  alias Philomena.Users.User
  alias Philomena.Posts.{Post, PostVersion}
  alias Philomena.Posts
  alias Philomena.IndexWorker
  alias Philomena.Forums
  alias Philomena.Forums.Forum
  alias Philomena.Forums.Visibility
  alias Philomena.Notifications
  alias Philomena.Reports
  alias Philomena.Versions
  alias Philomena.RateLimiter
  alias Philomena.Attribution.Actor
  alias PhilomenaQuery.Batch

  @post_create_window 15

  defp load_post_in_topic(%Actor{} = actor, topic, post_id, action) do
    with {:ok, post_id} <- Loader.parse_id(post_id) do
      Post
      |> where(topic_id: ^topic.id, id: ^post_id)
      |> Visibility.available_posts(actor)
      |> preload(topic: :forum, user: [awards: :badge])
      |> Loader.one_and_authorize(actor, action)
    end
  end

  defp notify_post(_repo, %{post: post, locked_topic: topic}) do
    Notifications.broadcast_forum_post(post.user, topic, post)
  end

  defp broadcast_post_creation(%{forum: %{access_level: "normal"}} = result) do
    PhilomenaWeb.Endpoint.broadcast!(
      "firehose",
      "post:create",
      PhilomenaWeb.Api.Json.Forum.Topic.PostView.render("firehose.json", result)
    )

    result
  end

  defp broadcast_post_creation(result), do: result

  defp put_reindex_post(%Multi{} = multi, step \\ :post) do
    Multi.on_commit(multi, fn %{^step => post} -> reindex_post(post) end)
  end

  @doc """
  Adds an `on_commit` step that reindexes all posts in a topic.

  `step` names the transaction result containing the topic and defaults to
  `:topic`. Indexing runs only after the transaction commits.

  ## Examples

      iex> Multi.new() |> put_reindex_posts_in_topic()
      %Multi{}

  """
  @spec put_reindex_posts_in_topic(Multi.t(), Multi.name()) :: Multi.t()
  def put_reindex_posts_in_topic(%Multi{} = multi, step \\ :topic) do
    Multi.on_commit(multi, fn %{^step => topic} -> reindex_posts_in_topic(topic) end)
  end

  @doc """
  Adds the steps for a post's approval transition.

  The callback receives the transaction changes and returns the post to
  inspect. If `became_unapproved?` is true, the post author's approved-post
  count is decremented and an Approval report is created. If
  `became_approved?` is true, the count is incremented again. Otherwise no
  steps are added.

  ## Examples

      iex> Multi.new() |> put_approval_report(fn changes -> changes.post end)
      %Multi{}

  """
  @spec put_approval_report(Multi.t(), (Multi.changes() -> Post.t())) :: Multi.t()
  def put_approval_report(%Multi{} = multi, post_callback)
      when is_function(post_callback, 1) do
    Multi.merge(multi, fn changes ->
      post = post_callback.(changes)

      cond do
        post.became_unapproved? ->
          Multi.new()
          |> UserStatistics.put_increment(post.user_id, :posts_count, -1)
          |> Reports.put_create_system_report(
            "Approval",
            "Post contains external links",
            :post_id,
            post.id
          )

        post.became_approved? ->
          UserStatistics.put_increment(Multi.new(), post.user_id, :posts_count)

        true ->
          Multi.new()
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> change_post(post)
      %Ecto.Changeset{source: %Post{}}

  """
  @spec change_post(Post.t()) :: Ecto.Changeset.t()
  def change_post(%Post{} = post) do
    Post.changeset(post, %{})
  end

  @doc """
  Loads one post visible to `actor` beneath its route forum and topic.

  The locator is safely parsed, and the post query is constrained by the loaded
  topic before authorization. Destroyed posts are not-found. Existing route
  members forbidden to the actor are unauthorized.

  ## Examples

      iex> show_topic_post(actor, "dis", "some-topic", "1")
      {:ok, %Post{}}

      iex> show_topic_post(actor, "dis", "some-topic", "not-a-number")
      {:error, :not_found}

  """
  @spec show_topic_post(
          Actor.t(),
          forum_slug :: String.t(),
          topic_slug :: String.t(),
          post_id :: Loader.integer_id()
        ) ::
          {:ok, Post.t()} | {:error, :not_found | :unauthorized}
  def show_topic_post(%Actor{} = actor, forum_slug, topic_slug, post_id) do
    with {:ok, forum} <- Forums.show_forum(actor, forum_slug),
         {:ok, topic} <- Topics.show_forum_topic(actor, forum, topic_slug, :show) do
      load_post_in_topic(actor, topic, post_id, :show)
    end
  end

  @doc """
  Loads one post visible to `actor` by its global ID.

  The ID is safely parsed, the parent topic and forum are preloaded, and the
  forum, topic, and post are authorized in hierarchy order. Destroyed,
  malformed, or missing posts are not-found.

  ## Examples

      iex> show_post(actor, "1")
      {:ok, %Post{}}

      iex> show_post(actor, "999999999")
      {:error, :not_found}

  """
  @spec show_post(Actor.t(), Loader.integer_id()) ::
          {:ok, Post.t()} | {:error, :not_found | :unauthorized}
  def show_post(%Actor{} = actor, post_id) do
    with {:ok, post_id} <- Loader.parse_id(post_id),
         {:ok, post} <-
           Post
           |> where(id: ^post_id)
           |> Visibility.available_posts(actor)
           |> preload([:user, topic: :forum])
           |> Loader.one(),
         :ok <- authorize(actor, :show, post.topic.forum),
         :ok <- authorize(actor, :show, post.topic),
         :ok <- authorize(actor, :show, post) do
      {:ok, post}
    end
  end

  @doc """
  Searches posts visible to `actor`, applying the compiled query string and
  pagination and sorting newest first.

  Moderators and administrators search every forum and visibility state.
  Assistants search normal and assistant forums. Other actors search visible
  posts in normal forums. Results carry the associations needed by both HTML
  and JSON renderers. An empty query compiles to an empty result.

  Returns `{:ok, results}`, or `{:error, msg}` when `query_string` fails to
  compile.

  ## Examples

      iex> query_posts(actor, "chartreuse", pagination)
      {:ok, %Scrivener.Page{}}

      iex> query_posts(actor, ")", pagination)
      {:error, "Imbalanced parentheses."}

  """
  @spec query_posts(Actor.t(), String.t() | nil, Search.pagination_params()) ::
          {:ok, Scrivener.Page.t()} | {:error, String.t()}
  def query_posts(%Actor{user: user} = actor, query_string, pagination) do
    with {:ok, query} <- Posts.Query.compile(query_string, user: user) do
      results =
        Post
        |> Search.search_definition(
          %{
            query: %{
              bool: %{
                must: query,
                filter: Visibility.search_filters(actor)
              }
            },
            sort: %{created_at: :desc}
          },
          pagination
        )
        |> Search.search_records(
          preload(Post, [:deleted_by, topic: :forum, user: [awards: :badge]])
        )

      {:ok, results}
    end
  end

  @doc """
  Creates a reply on behalf of `actor` in the topic named by `topic_slug`
  within the forum named by `forum_slug`, from `params`.

  `actor`'s write access is verified first. Then the forum is
  loaded by short name and authorized for `:show`, the topic is loaded by slug
  with hidden topics kept invisible unless the actor may `:show` them, and the
  actor is authorized for `:create_post` on the topic (which no rule permits on a
  locked or hidden topic). The reply is then inserted.

  On a successful insert, an approved post increments its author's forum post
  count and an unapproved one is reported for containing external links. The
  returned map carries the post, topic, and forum needed for the firehose
  broadcast and for the caller to reuse.

  ## Return shapes

  - `{:ok, post}` on success (the post carries its topic and forum)
  - `{:error, changeset}` when the insert is rejected
  - `{:error, :ban}` or `{:error, :unauthorized}` from the write-access check
  - `{:error, :unauthorized}` when the forum or topic is not visible or the topic may not be posted in
  - `{:error, :not_found}` when the topic does not exist
  - `{:error, :rate_limited}` when a non-exempt actor has posted within the last 15 seconds

  ## Examples

      iex> create_post(actor, "dis", "some-topic", %{"body" => "Hi"})
      {:ok, %Post{}}

      iex> create_post(actor, "dis", "some-topic", %{"body" => ""})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_post(
          actor :: Actor.t(),
          forum_slug :: String.t(),
          topic_slug :: String.t(),
          params :: map()
        ) ::
          {:ok, Post.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found | :rate_limited}
  def create_post(%Actor{user: creator} = actor, forum_slug, topic_slug, params) do
    with :ok <- verify_write_access(actor) do
      Multi.new()
      |> Multi.reserve_action(
        fn -> RateLimiter.record_action(actor, :post_create, @post_create_window) end,
        fn -> RateLimiter.rollback_action(actor, :post_create) end
      )
      |> put_forum_and_topic_locks(actor, forum_slug, :show, topic_slug, :create_post)
      |> put_max_topic_position()
      |> Multi.insert(:post, fn %{max_topic_position: max_topic_position, locked_topic: topic} ->
        topic
        |> Ecto.build_assoc(:posts, topic_position: (max_topic_position || -1) + 1)
        |> Map.put(:topic, topic)
        |> Post.creation_changeset(params, actor)
      end)
      |> Topics.put_post_visibility_counters(visible?: true)
      |> Topics.put_refresh_last_post()
      |> Forums.put_post_visibility_counters(visible?: true)
      |> Forums.put_refresh_last_post()
      |> Topics.maybe_subscribe_on(:locked_topic, creator, :watch_on_reply)
      |> Multi.run(:notification, &notify_post/2)
      |> UserStatistics.put_increment(creator, :posts_count)
      |> put_approval_report(fn %{post: post} -> post end)
      |> put_reindex_post()
      |> Multi.transact()
      |> case do
        {:ok, %{locked_forum: %Forum{} = forum, post: %Post{} = post}} ->
          # The firehose representation includes the topic author.
          broadcast_post_creation(%{
            post: post,
            topic: Repo.preload(post.topic, :user),
            forum: forum
          })

          {:ok, post}

        {:error, :action_reservation, :rate_limited, _changes} ->
          {:error, :rate_limited}

        {:error, :post, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Loads the post named by `post_id` within the topic named by
  `topic_slug` in the forum named by `forum_slug` for editing, on behalf of
  `actor`.

  A ban is checked first; a missing fingerprint is left to `update_post/5`.
  The forum, topic, and post are then parent-scoped and authorized for `:edit`.

  Returns `{:ok, changeset}` - the changeset's data is the post with its topic,
  forum, and author preloaded -
  `{:error, :ban}` for a banned actor, `{:error, :unauthorized}` when the forum,
  topic, or post is not visible or may not be edited, or `{:error, :not_found}`
  when the topic or post does not exist.

  ## Examples

      iex> edit_post(actor, "dis", "some-topic", "1")
      {:ok, %Ecto.Changeset{}}

  """
  @spec edit_post(
          actor :: Actor.t(),
          forum_slug :: String.t(),
          topic_slug :: String.t(),
          Loader.integer_id()
        ) ::
          {:ok, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found}
  def edit_post(actor, forum_slug, topic_slug, post_id) do
    with :ok <- verify_not_banned(actor),
         {:ok, forum} <- Forums.show_forum(actor, forum_slug),
         {:ok, topic} <- Topics.show_forum_topic(actor, forum, topic_slug, :create_post),
         {:ok, post} <- load_post_in_topic(actor, topic, post_id, :edit) do
      {:ok, change_post(post)}
    end
  end

  @doc """
  Updates the post named by `post_id` within the topic named by
  `topic_slug` in the forum named by `forum_slug` from `params`, on behalf
  of `actor`.

  `actor`'s write access is verified first, before the same load-and-authorize chain
  `load_post_for_edit/4` uses (see `load_editable_post/4`). The edit is then applied
  by `update_post/5`, recording a version attributed to `actor`'s user; an unapproved
  result is reported for containing external links (an approved result is a no-op).

  ## Return shapes

  - `{:ok, post}` on success (the post carries its topic and forum for the caller to reuse)
  - `{:error, changeset}` when the edit is rejected; `changeset.data` is the loaded post
  - `{:error, :ban}` or `{:error, :unauthorized}` from the write-access check
  - `{:error, :unauthorized}` when the forum, topic, or post is not visible or may not be edited
  - `{:error, :not_found}` when the topic or post does not exist

  ## Examples

      iex> update_post(actor, "dis", "some-topic", "1", %{"body" => "Edited"})
      {:ok, %Post{}}

      iex> update_post(actor, "dis", "some-topic", "1", %{"body" => ""})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_post(
          actor :: Actor.t(),
          forum_slug :: String.t(),
          topic_slug :: String.t(),
          post_id :: Loader.integer_id(),
          params :: map()
        ) ::
          {:ok, Post.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found}
  def update_post(%Actor{} = actor, forum_slug, topic_slug, post_id, params) do
    with :ok <- verify_write_access(actor),
         {:ok, post_id} <- Loader.parse_id(post_id) do
      Multi.new()
      |> put_forum_and_topic_and_post_locks(
        actor,
        forum_slug,
        :show,
        topic_slug,
        :create_post,
        post_id,
        :update
      )
      |> Multi.update(:post, fn %{locked_post: post} ->
        Post.changeset(post, params, DateTime.utc_now(:second))
      end)
      |> Versions.record_edit(:version, :locked_post, :post, actor)
      |> put_approval_report(fn %{post: post} -> post end)
      |> put_reindex_post()
      |> Multi.transact()
      |> case do
        {:ok, %{post: %Post{} = post}} ->
          {:ok, post}

        {:error, :post, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Hides the post named by `post_id`, recording the
  `deletion_reason` carried in `params`, on behalf of `actor`.

  The post is authorized for `:hide`. On success, the post's
  associated reports are closed, the topic's and forum's last-post pointers are
  refreshed, the post is reindexed, and a moderation log is written attributing
  the deletion to `actor`.

  The post is loaded (and returned) with its `:topic` and the topic's `:forum`
  preloaded so the caller can reuse them for either outcome.
  A rejected hide changeset (e.g. a blank deletion reason) returns
  `{:error, changeset}` carrying the loaded post in `changeset.data`.

  ## Examples

      iex> create_post_hide(moderator_actor, "dis", "some-topic", "1", %{"deletion_reason" => "Spam"})
      {:ok, %Post{}}

      iex> create_post_hide(moderator_actor, "dis", "some-topic", "1", %{"deletion_reason" => ""})
      {:error, %Ecto.Changeset{}}

      iex> create_post_hide(user_actor, "dis", "some-topic", "1", %{"deletion_reason" => "Spam"})
      {:error, :unauthorized}

  """
  @spec create_post_hide(Actor.t(), String.t(), String.t(), Loader.integer_id(), map()) ::
          {:ok, Post.t()}
          | {:error, :ban | :unauthorized | :not_found}
          | {:error, Ecto.Changeset.t()}
  def create_post_hide(%Actor{user: user} = actor, forum_slug, topic_slug, post_id, params) do
    with :ok <- verify_write_access(actor),
         {:ok, post_id} <- Loader.parse_id(post_id) do
      Multi.new()
      |> put_forum_and_topic_and_post_locks(
        actor,
        forum_slug,
        :show,
        topic_slug,
        :show,
        post_id,
        :hide
      )
      |> Multi.update(:post, fn %{locked_post: post} ->
        Post.hide_changeset(post, params, user)
      end)
      |> Reports.put_close_reports(:reports, user, post_id: post_id)
      |> Topics.put_refresh_last_post()
      |> Forums.put_refresh_last_post()
      |> put_reindex_post()
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{locked_topic: topic, post: post} ->
          {
            "Topic.Post.Hide:create",
            Paths.forum_post_path(post),
            "Deleted forum post ##{post.id} in topic '#{topic.title}' (#{post.deletion_reason})"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{post: %Post{} = post}} ->
          {:ok, post}

        {:error, :post, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Restores the post named by `post_id`, on behalf of `actor`.

  Loading and authorization mirror `hide_post/5`. On success the topic's and
  forum's last-post pointers are refreshed, the post is reindexed, and a
  moderation log is written attributing the restore to `actor`.

  The post is loaded (and returned) with its `:topic` and the topic's `:forum`
  preloaded so the caller can reuse them. A rejected restore
  returns `{:error, changeset}` carrying the loaded post in `changeset.data`.

  ## Examples

      iex> delete_post_hide(moderator_actor, "dis", "some-topic", "1")
      {:ok, %Post{}}

      iex> delete_post_hide(user_actor, "dis", "some-topic", "1")
      {:error, :unauthorized}

  """
  @spec delete_post_hide(Actor.t(), String.t(), String.t(), Loader.integer_id()) ::
          {:ok, Post.t()}
          | {:error, :ban | :unauthorized | :not_found}
          | {:error, Ecto.Changeset.t()}
  def delete_post_hide(%Actor{} = actor, forum_slug, topic_slug, post_id) do
    with :ok <- verify_write_access(actor),
         {:ok, post_id} <- Loader.parse_id(post_id) do
      Multi.new()
      |> put_forum_and_topic_and_post_locks(
        actor,
        forum_slug,
        :show,
        topic_slug,
        :show,
        post_id,
        :unhide
      )
      |> Multi.update(:post, fn %{locked_post: post} -> Post.unhide_changeset(post) end)
      |> Topics.put_refresh_last_post()
      |> Forums.put_refresh_last_post()
      |> put_reindex_post()
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{locked_topic: topic, post: post} ->
          {
            "Topic.Post.Hide:delete",
            Paths.forum_post_path(post),
            "Restored forum post ##{post.id} in topic '#{topic.title}'"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{post: %Post{} = post}} ->
          {:ok, post}

        {:error, :post, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Destroys (permanently wipes the text of) the post named by
  `post_id`, on behalf of `actor`.

  The post is authorized for `:delete`. On success, the post's
  text is blanked, the topic's and forum's post counts and the author's forum
  post count are decremented, the post is reindexed, and a moderation log is
  written attributing the destruction to `actor`.

  The post is loaded (and returned) with its `:topic` and the topic's `:forum`
  preloaded so the caller can reuse them for either outcome.
  A failed destroy returns `{:error, changeset}` carrying the loaded post in
  `changeset.data`.

  ## Examples

      iex> create_post_delete(moderator_actor, "dis", "some-topic", "1")
      {:ok, %Post{}}

      iex> create_post_delete(user_actor, "dis", "some-topic", "1")
      {:error, :unauthorized}

      iex> create_post_delete(moderator_actor, "dis", "some-topic", "not-an-integer")
      {:error, :not_found}

  """
  @spec create_post_delete(Actor.t(), String.t(), String.t(), Loader.integer_id()) ::
          {:ok, Post.t()}
          | {:error, :ban | :unauthorized | :not_found}
          | {:error, Ecto.Changeset.t()}
  def create_post_delete(%Actor{} = actor, forum_slug, topic_slug, post_id) do
    with :ok <- verify_write_access(actor),
         {:ok, post_id} <- Loader.parse_id(post_id) do
      Multi.new()
      |> put_forum_and_topic_and_post_locks(
        actor,
        forum_slug,
        :show,
        topic_slug,
        :show,
        post_id,
        :delete
      )
      |> Multi.update(:post, fn %{locked_post: post} -> Post.destroy_changeset(post) end)
      |> Topics.put_post_visibility_counters(visible?: false)
      |> Forums.put_post_visibility_counters(visible?: false)
      |> UserStatistics.put_increment(
        fn %{post: post} ->
          if post.approved, do: post.user_id
        end,
        :posts_count,
        -1
      )
      |> put_reindex_post()
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{locked_topic: topic, post: post} ->
          {
            "Topic.Post.Delete:create",
            Paths.forum_post_path(post),
            "Destroyed forum post ##{post.id} in topic '#{topic.title}'"
          }
        end
      )
      |> Multi.transact()
      |> case do
        {:ok, %{post: %Post{} = post}} ->
          {:ok, post}

        {:error, :post, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Approves the post named by `post_id`, on behalf of `actor`.

  The post is authorized for `:approve`. On success, the post's associated
  reports are closed, the author's forum post count is incremented, the post
  is reindexed, and a moderation log is written attributing the approval to `actor`.

  The post is loaded (and returned) with its `:topic` and the topic's `:forum`
  preloaded so the caller can reuse them for either outcome. A failed approval
  changeset returns `{:error, changeset}` carrying the loaded post in
  `changeset.data`.

  ## Examples

      iex> create_post_approve(moderator_actor, "dis", "some-topic", "1")
      {:ok, %Post{}}

      iex> create_post_approve(user_actor, "dis", "some-topic", "1")
      {:error, :unauthorized}

      iex> create_post_approve(moderator_actor, "dis", "some-topic", "not-an-integer")
      {:error, :not_found}

  """
  @spec create_post_approve(Actor.t(), String.t(), String.t(), Loader.integer_id()) ::
          {:ok, Post.t()}
          | {:error, :ban | :unauthorized | :not_found}
          | {:error, Ecto.Changeset.t()}
  def create_post_approve(%Actor{user: user} = actor, forum_slug, topic_slug, post_id) do
    with :ok <- verify_write_access(actor),
         {:ok, post_id} <- Loader.parse_id(post_id) do
      Multi.new()
      |> put_forum_and_topic_and_post_locks(
        actor,
        forum_slug,
        :show,
        topic_slug,
        :show,
        post_id,
        :approve
      )
      |> Multi.update(:post, fn %{locked_post: post} -> Post.approve_changeset(post) end)
      |> Reports.put_close_reports(:reports, user, post_id: post_id)
      |> put_reindex_post()
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        fn %{locked_topic: topic, post: post} ->
          {
            "Topic.Post.Approve:create",
            Paths.forum_post_path(post),
            "Approved forum post ##{post.id} in topic '#{topic.title}'"
          }
        end
      )
      |> UserStatistics.put_increment(fn %{post: post} -> post.user_id end, :posts_count)
      |> Multi.transact()
      |> case do
        {:ok, %{post: %Post{} = post}} ->
          {:ok, post}

        {:error, :post, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        error ->
          map_lock_errors(error)
      end
    end
  end

  @doc """
  Loads the edit history of the post named by `post_id` within
  the topic named by `topic_slug` in the forum named by `forum_slug`, on behalf
  of `actor`.

  The forum is loaded by short name and authorized for `:show`, and the topic is
  loaded by slug with hidden topics visible only to actors who may `:show` them.
  The post is then loaded by id within that topic: malformed, missing, and
  wrong-topic IDs return `{:error, :not_found}`. A post hidden from users is
  visible only when `actor` may `:show` it, otherwise
  `{:error, :unauthorized}`.

  On success the loaded post (with its topic, forum, and author associations
  preloaded) is returned alongside the topic and the last 25 versions of the
  post, newest first, with diffs and version authors resolved.

  Returns `{:ok, {topic, post, versions}}`, `{:error, :unauthorized}` when the
  forum, topic, or hidden post is not visible to `actor`, or
  `{:error, :not_found}` when the topic or post does not exist.

  ## Examples

      iex> list_post_history(user, "dis", "some-topic", "1")
      {:ok, {%Topic{}, %Post{}, [%Version{}, ...]}}

      iex> list_post_history(user, "dis", "some-topic", "999999999")
      {:error, :not_found}

  """
  @spec list_post_history(
          actor :: Actor.t(),
          forum_slug :: String.t(),
          topic_slug :: String.t(),
          post_id :: Loader.integer_id()
        ) ::
          {:ok, {Topic.t(), Post.t(), [PostVersion.t()]}}
          | {:error, :unauthorized | :not_found}
  def list_post_history(%Actor{} = actor, forum_slug, topic_slug, post_id) do
    with {:ok, forum} <- Forums.show_forum(actor, forum_slug),
         {:ok, topic} <- Topics.show_forum_topic(actor, forum, topic_slug, :show),
         {:ok, post} <- load_post_in_topic(actor, topic, post_id, :show) do
      {:ok, {topic, post, Versions.for_post(post)}}
    end
  end

  @doc """
  Loads a post as a report target within its route forum and topic.

  The forum and topic visibility checks run before the post is loaded through a
  parent-scoped query. Malformed, missing, and mismatched post IDs are always
  not-found. The Reports context owns write access and form construction.

  ## Examples

      iex> load_report_target(actor, "dis", "some-topic", "1")
      {:ok, %Post{}}
  """
  @spec load_report_target(
          actor :: Actor.t(),
          forum_slug :: String.t(),
          topic_slug :: String.t(),
          post_id :: Loader.integer_id()
        ) ::
          {:ok, Post.t()} | {:error, :unauthorized | :not_found}
  def load_report_target(%Actor{} = actor, forum_slug, topic_slug, post_id) do
    with {:ok, forum} <- Forums.show_forum(actor, forum_slug),
         {:ok, topic} <- Topics.show_forum_topic(actor, forum, topic_slug, :show) do
      load_post_in_topic(actor, topic, post_id, :show)
    end
  end

  @doc """
  Replaces attribution data on a user's posts in batches.
  """
  @spec wipe_user_attribution!(integer(), term(), String.t()) :: :ok
  def wipe_user_attribution!(user_id, ip, fingerprint) do
    Post
    |> where(user_id: ^user_id)
    |> Batch.query_batches()
    |> Enum.each(&Repo.update_all(&1, set: [ip: ip, fingerprint: fingerprint]))

    :ok
  end

  @doc """
  Updates post search indices when a user's name changes.

  ## Examples

      iex> user_name_reindex("old_username", "new_username")
      :ok

  """
  @spec user_name_reindex(String.t(), String.t()) :: term()
  def user_name_reindex(old_name, new_name) do
    data = Posts.SearchIndex.user_name_update_by_query(old_name, new_name)

    Search.update_by_query(Post, data.query, data.set_replacements, data.replacements)
  end

  @doc """
  Queues a single post for search index updates.
  Returns the post struct unchanged, for use in a pipeline.

  ## Examples

      iex> reindex_post(post)
      %Post{}

  """
  @spec reindex_post(Post.t()) :: Post.t()
  def reindex_post(%Post{} = post) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Posts", "id", [post.id]])

    post
  end

  @doc """
  Queues every post in the given topic for search index updates.

  Used when a topic's visibility changes: a post's indexed `hidden_from_users`
  reflects its topic's hidden state (see `Philomena.Posts.SearchIndex`), so
  hiding or unhiding a topic must refresh all of its posts.

  ## Examples

      iex> reindex_posts_in_topic(topic_id)
      :ok

  """
  @spec reindex_posts_in_topic(Topic.t()) :: :ok
  def reindex_posts_in_topic(%Topic{} = topic) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Posts", "topic_id", [topic.id]])

    :ok
  end

  @doc """
  Provides preload queries for post indexing operations.

  ## Examples

      iex> indexing_preloads()
      [user: user_query, topic: topic_query]

  """
  @spec indexing_preloads() :: list()
  def indexing_preloads do
    user_query = select(User, [u], map(u, [:id, :name]))

    topic_query =
      Topic
      |> select([t], struct(t, [:forum_id, :title, :hidden_from_users]))
      |> preload([:forum])

    [
      user: user_query,
      topic: topic_query,
      deleted_by: user_query
    ]
  end

  @doc """
  Performs a search reindex operation on posts matching the given criteria.

  ## Parameters
  - column: The database column to filter on (e.g., :id, :topic_id)
  - condition: A list of values to match against the column

  ## Examples

      iex> perform_reindex(:id, [1, 2, 3])
      :ok

      iex> perform_reindex(:topic_id, [123])
      :ok

  """
  @spec perform_reindex(atom(), [term()]) :: term()
  def perform_reindex(column, condition) do
    Post
    |> preload(^indexing_preloads())
    |> where([p], field(p, ^column) in ^condition)
    |> Search.reindex(Post)
  end
end
