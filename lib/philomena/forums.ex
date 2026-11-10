defmodule Philomena.Forums do
  @moduledoc """
  Forum discovery, subscription state, and staff-managed forum settings.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Attribution.Actor
  alias Philomena.Forums.{Forum, ForumIndex, ForumPage}
  alias Philomena.Forums.Visibility
  alias Philomena.Loader
  alias Philomena.Multi
  alias Philomena.Repo
  alias Philomena.Topics.Topic

  use Philomena.Subscriptions, id_name: :forum_id

  defp load_authorized_forum(actor, action, short_name) do
    Forum
    |> where([forum], forum.short_name == ^short_name)
    |> Loader.one_and_authorize(actor, action)
  end

  defp visible_forums_query(actor) do
    Forum
    |> Visibility.visible_forums(actor)
    |> order_by(asc: :name)
  end

  @doc """
  Lists the forums visible to `actor`, ordered by name.

  ## Examples

      iex> list_forums(actor)
      [%Forum{}, ...]

  """
  @spec list_forums(Actor.t()) :: [Forum.t()]
  def list_forums(%Actor{} = actor) do
    actor
    |> visible_forums_query()
    |> Repo.all()
  end

  @doc """
  Lists the forums visible to `actor`, ordered by name, with pagination and
  aggregate topic count.

  The topic count includes only topics whose parent forum and topic are visible
  to the actor.

  ## Examples

      iex> list_forums(actor)
      %ForumIndex{forums: [%Forum{}], topic_count: 42}

  """
  @spec list_forums(Actor.t(), Repo.pagination_params()) :: ForumIndex.t()
  def list_forums(%Actor{} = actor, pagination) do
    forums = visible_forums_query(actor)
    topic_count = Repo.aggregate(forums, :sum, :topic_count)

    forums =
      forums
      |> preload(last_post: [:user, topic: :forum])
      |> Repo.paginate(pagination)

    %ForumIndex{forums: forums, topic_count: topic_count}
  end

  @doc """
  Loads every forum for the staff administration index.

  ## Examples

      iex> list_admin_forums(admin_actor)
      {:ok, [%Forum{}]}

  """
  @spec list_admin_forums(Actor.t()) :: {:ok, [Forum.t()]} | {:error, :unauthorized}
  def list_admin_forums(%Actor{} = actor) do
    with :ok <- authorize(actor, :manage, Forum) do
      {:ok, list_forums(actor)}
    end
  end

  @doc """
  Loads a forum visible to `actor` by short name.

  Malformed or unknown names are not-found; a real restricted forum is
  unauthorized.

  ## Examples

      iex> show_forum(actor, "dis")
      {:ok, %Forum{}}

      iex> show_forum(actor, "missing")
      {:error, :not_found}

  """
  @spec show_forum(Actor.t(), String.t()) ::
          {:ok, Forum.t()} | {:error, :not_found | :unauthorized}
  def show_forum(%Actor{} = actor, short_name) do
    load_authorized_forum(actor, :show, short_name)
  end

  @doc """
  Loads a visible forum and its topic page.

  ## Examples

      iex> show_forum_page(actor, "dis", pagination)
      {:ok, %ForumPage{}}

  """
  @spec show_forum_page(Actor.t(), String.t(), Repo.pagination_params()) ::
          {:ok, ForumPage.t()} | {:error, :not_found | :unauthorized}
  def show_forum_page(%Actor{} = actor, short_name, pagination) do
    with {:ok, forum} <- load_authorized_forum(actor, :show, short_name) do
      topics =
        Topic
        |> where([topic], topic.forum_id == ^forum.id)
        |> where(hidden_from_users: false)
        |> order_by(desc: :sticky, desc: :last_replied_to_at, desc: :id)
        |> preload([:poll, :forum, :user, last_post: :user])
        |> Repo.paginate(pagination)

      {:ok,
       %ForumPage{
         forum: forum,
         topics: topics,
         watching: subscribed?(forum, actor.user)
       }}
    end
  end

  @doc """
  Subscribes `actor` to a visible forum. Subscription management is
  deliberately exempt from `verify_write_access/1`.

  ## Examples

      iex> create_forum_subscription(actor, "dis")
      {:ok, %Forum{}}

  """
  @spec create_forum_subscription(Actor.t(), String.t()) ::
          {:ok, Forum.t()} | {:error, :not_found | :unauthorized | Ecto.Changeset.t()}
  def create_forum_subscription(%Actor{} = actor, short_name) do
    with {:ok, forum} <- load_authorized_forum(actor, :subscribe, short_name),
         {:ok, _subscription} <- create_subscription(forum, actor.user) do
      {:ok, forum}
    end
  end

  @doc """
  Idempotently unsubscribes `actor` from a visible forum. Subscription
  management is deliberately exempt from `verify_write_access/1`.

  ## Examples

      iex> delete_forum_subscription(actor, "dis")
      {:ok, %Forum{}}

  """
  @spec delete_forum_subscription(Actor.t(), String.t()) ::
          {:ok, Forum.t()} | {:error, :not_found | :unauthorized}
  def delete_forum_subscription(%Actor{} = actor, short_name) do
    with {:ok, forum} <- load_authorized_forum(actor, :unsubscribe, short_name),
         {:ok, _subscription} <- delete_subscription(forum, actor.user) do
      {:ok, forum}
    end
  end

  @doc """
  Builds an authorized forum creation form.

  ## Examples

      iex> new_forum(admin_actor)
      {:ok, %Ecto.Changeset{}}

  """
  @spec new_forum(Actor.t()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :unauthorized}
  def new_forum(%Actor{} = actor) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :new, Forum) do
      {:ok, Forum.changeset(%Forum{})}
    end
  end

  @doc """
  Creates a forum on behalf of an authorized actor.

  ## Examples

      iex> create_forum(admin_actor, attrs)
      {:ok, %Forum{}}

      iex> create_forum(admin_actor, invalid_attrs)
      {:error, %Ecto.Changeset{}}

  """
  @spec create_forum(Actor.t(), map()) ::
          {:ok, Forum.t()} | {:error, :ban | :unauthorized | Ecto.Changeset.t()}
  def create_forum(%Actor{} = actor, attrs) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, Forum) do
      %Forum{}
      |> Forum.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Loads a forum edit form by short name.

  ## Examples

      iex> edit_forum(admin_actor, "dis")
      {:ok, {%Forum{}, %Ecto.Changeset{}}}

  """
  @spec edit_forum(Actor.t(), String.t()) ::
          {:ok, {Forum.t(), Ecto.Changeset.t()}} | {:error, :ban | :not_found | :unauthorized}
  def edit_forum(%Actor{} = actor, short_name) do
    with :ok <- verify_not_banned(actor),
         {:ok, forum} <- load_authorized_forum(actor, :edit, short_name) do
      {:ok, {forum, Forum.changeset(forum, %{})}}
    end
  end

  @doc """
  Updates a forum selected by short name.

  ## Examples

      iex> update_forum(admin_actor, "dis", attrs)
      {:ok, %Forum{}}

  """
  @spec update_forum(Actor.t(), String.t(), map()) ::
          {:ok, Forum.t()} | {:error, :ban | :not_found | :unauthorized | Ecto.Changeset.t()}
  def update_forum(%Actor{} = actor, short_name, attrs) do
    with :ok <- verify_write_access(actor),
         {:ok, forum} <- load_authorized_forum(actor, :update, short_name) do
      forum
      |> Forum.changeset(attrs)
      |> Repo.update()
    end
  end

  @doc """
  Adds an update step that recalculates a forum's cached last visible post.

  Maintains `Forum.last_post_id` as the highest-ID post that is visible and
  belongs to a non-hidden topic in that forum. The step reads the locked forum
  from `forum_step`, which defaults to `:locked_forum`. Add it after a reply,
  post visibility change, topic visibility change, or topic move; a move must
  refresh both locked forums.

  ## Examples

      iex> (Multi.new()
      ...> |> put_forum_and_topic_locks(actor, "dis", :show, "topic", :hide)
      ...> |> Multi.update(:topic, topic_changeset)
      ...> |> Forums.put_refresh_forum_last_post())
      %Multi{}

  """
  @spec put_refresh_last_post(Multi.t(), Multi.name()) :: Multi.t()
  def put_refresh_last_post(%Multi{} = multi, forum_step \\ :locked_forum) do
    Multi.update_all(
      multi,
      {:refresh_forum_last_post, forum_step},
      fn %{^forum_step => forum} -> update_last_post_query(forum.id) end,
      []
    )
  end

  @doc """
  Adds forum counter updates for a topic transfer.

  Maintains `Forum.topic_count` and `Forum.post_count` for both forums. The
  updated topic is read from `:topic`. When it is visible, its one-topic and
  complete `post_count` contribution is moved from `:locked_source_forum` to
  `:locked_target_forum`. A hidden topic contributes to neither forum, so no
  counters change. Call this immediately after moving the topic and before
  refreshing the last-post pointers of both locked forums.

  ## Examples

      iex> (Multi.new()
      ...> |> put_source_and_target_forum_and_topic_locks(actor, "dis", :show, "gen", :show, "topic", :move)
      ...> |> Multi.update(:topic, topic_changeset)
      ...> |> Forums.put_topic_transfer_counters())
      %Multi{}

  """
  @spec put_topic_transfer_counters(Multi.t()) :: Multi.t()
  def put_topic_transfer_counters(%Multi{} = multi) do
    Multi.merge(multi, fn
      %{topic: %{hidden_from_users: true}} ->
        # Hidden topics do not contribute to forum post count.
        Multi.new()

      %{locked_source_forum: source, locked_target_forum: target, topic: topic} ->
        Multi.new()
        |> Multi.update_all(
          :source_forum_count,
          Forum
          |> where(id: ^source.id)
          |> update(inc: [post_count: ^(-topic.post_count), topic_count: -1]),
          []
        )
        |> Multi.update_all(
          :target_forum_count,
          Forum
          |> where(id: ^target.id)
          |> update(inc: [post_count: ^topic.post_count, topic_count: 1]),
          []
        )
    end)
  end

  @doc """
  Adds counter updates for a topic becoming visible or hidden.

  Maintains `Forum.topic_count`, `Forum.post_count`, and the topic author's
  `topics_count`. `visible?: true` adds one topic and that topic's complete
  non-destroyed `post_count`; `false` removes the same contribution. The
  transaction must contain `:locked_forum` and the updated `:topic`, and must
  call this immediately after changing `Topic.hidden_from_users`.

  ## Examples

      iex> (Multi.new()
      ...> |> put_forum_and_topic_locks(actor, "dis", :show, "topic", :unhide)
      ...> |> Multi.update(:topic, topic_changeset)
      ...> |> Forums.put_topic_visibility_counters(visible?: true))
      %Multi{}

  """
  @spec put_topic_visibility_counters(Multi.t(), [{:visible?, boolean()}]) :: Multi.t()
  def put_topic_visibility_counters(%Multi{} = multi, [{:visible?, visible?}]) do
    scale = if visible?, do: 1, else: -1

    Multi.update_all(
      multi,
      :forum_topic_visibility_count,
      fn %{locked_forum: forum, topic: topic} ->
        Forum
        |> where(id: ^forum.id)
        |> update(inc: [post_count: ^(scale * topic.post_count), topic_count: ^scale])
      end,
      []
    )
  end

  @doc """
  Adds a forum post counter update for post creation or destruction.

  Maintains `Forum.post_count`. `visible?: true` increments it and `false`
  decrements it, but only when `:locked_topic` is visible. Hidden topics do not
  contribute posts to their forum. The transaction must contain
  `:locked_forum` and `:locked_topic`, and call this after the post mutation.
  Pair it with `put_post_topic_visibility_counters/2` whenever a post is created
  or destroyed.

  ## Examples

      iex> (Multi.new()
      ...> |> put_forum_and_topic_and_post_locks(actor, "dis", :show, "topic", :show, 1, :delete)
      ...> |> Multi.update(:post, post_changeset)
      ...> |> Topics.put_post_visibility_counters(visible?: false)
      ...> |> Forums.put_post_visibility_counters(visible?: false))
      %Multi{}

  """
  @spec put_post_visibility_counters(Multi.t(), [{:visible?, boolean()}]) :: Multi.t()
  def put_post_visibility_counters(%Multi{} = multi, [{:visible?, visible?}]) do
    Multi.merge(multi, fn
      %{locked_topic: %{hidden_from_users: true}} ->
        # Hidden topics do not contribute to forum post count.
        Multi.new()

      %{locked_forum: forum} ->
        scale = if visible?, do: 1, else: -1

        query =
          Forum
          |> where(id: ^forum.id)
          |> update(inc: [post_count: ^scale])

        Multi.update_all(Multi.new(), :forum_post_count, query, [])
    end)
  end

  defp update_last_post_query(forum_id) do
    Forum
    |> where(id: ^forum_id)
    |> update(
      set: [
        last_post_id:
          fragment(
            """
            SELECT last_post_id FROM topics
            WHERE forum_id = ?
            AND hidden_from_users IS FALSE
            AND last_post_id IS NOT NULL
            ORDER BY last_replied_to_at DESC, id DESC
            LIMIT 1
            """,
            ^forum_id
          )
      ]
    )
  end
end
