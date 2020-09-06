defmodule Philomena.Posts do
  @moduledoc """
  The Posts context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Elasticsearch
  alias Philomena.Topics.Topic
  alias Philomena.Topics
  alias Philomena.Posts.Post
  alias Philomena.Posts.ElasticsearchIndex, as: PostIndex
  alias Philomena.Forums.Forum
  alias Philomena.Notifications
  alias Philomena.Versions
  alias Philomena.Reports.Report

  @doc """
  Gets a single post.

  Raises `Ecto.NoResultsError` if the Post does not exist.

  ## Examples

      iex> get_post!(123)
      %Post{}

      iex> get_post!(456)
      ** (Ecto.NoResultsError)

  """
  def get_post!(id), do: Repo.get!(Post, id)

  @doc """
  Creates a post.

  ## Examples

      iex> create_post(%{field: value})
      {:ok, %Post{}}

      iex> create_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(topic, attributes, params \\ %{}) do
    now = DateTime.utc_now()

    topic_query =
      Topic
      |> where(id: ^topic.id)

    forum_query =
      Forum
      |> where(id: ^topic.forum_id)

    Multi.new()
    |> Multi.run(:post, fn repo, _ ->
      last_position =
        Post
        |> where(topic_id: ^topic.id)
        |> order_by(desc: :topic_position)
        |> select([p], p.topic_position)
        |> limit(1)
        |> repo.one()

      Ecto.build_assoc(topic, :posts, [topic_position: (last_position || -1) + 1] ++ attributes)
      |> Post.creation_changeset(params, attributes)
      |> repo.insert()
    end)
    |> Multi.run(:update_topic, fn repo, %{post: %{id: post_id}} ->
      {count, nil} =
        repo.update_all(topic_query,
          inc: [post_count: 1],
          set: [last_post_id: post_id, last_replied_to_at: now]
        )

      {:ok, count}
    end)
    |> Multi.run(:update_forum, fn repo, %{post: %{id: post_id}} ->
      {count, nil} =
        repo.update_all(forum_query, inc: [post_count: 1], set: [last_post_id: post_id])

      {:ok, count}
    end)
    |> Multi.run(:subscribe, fn _repo, _changes ->
      Topics.create_subscription(topic, attributes[:user])
    end)
    |> Repo.transaction()
  end

  def notify_post(post) do
    spawn(fn ->
      topic =
        post
        |> Repo.preload(:topic)
        |> Map.fetch!(:topic)

      subscriptions =
        topic
        |> Repo.preload(:subscriptions)
        |> Map.fetch!(:subscriptions)

      Notifications.notify(
        post,
        subscriptions,
        %{
          actor_id: topic.id,
          actor_type: "Topic",
          actor_child_id: post.id,
          actor_child_type: "Post",
          action: "posted a new reply in"
        }
      )
    end)

    post
  end

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Post{} = post, editor, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    current_body = post.body
    current_reason = post.edit_reason

    post_changes = Post.changeset(post, attrs, now)

    Multi.new()
    |> Multi.update(:post, post_changes)
    |> Multi.run(:version, fn _repo, _changes ->
      Versions.create_version("Post", post.id, editor.id, %{
        "body" => current_body,
        "edit_reason" => current_reason
      })
    end)
    |> Repo.transaction()
  end

  @doc """
  Deletes a Post.

  ## Examples

      iex> delete_post(post)
      {:ok, %Post{}}

      iex> delete_post(post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  def hide_post(%Post{} = post, attrs, user) do
    reports =
      Report
      |> where(reportable_type: "Post", reportable_id: ^post.id)
      |> select([r], r.id)
      |> update(set: [open: false, state: "closed"])

    post = Post.hide_changeset(post, attrs, user)

    Multi.new()
    |> Multi.update(:post, post)
    |> Multi.update_all(:reports, reports, [])
    |> Repo.transaction()
  end

  def unhide_post(%Post{} = post) do
    post
    |> Post.unhide_changeset()
    |> Repo.update()
  end

  def destroy_post(%Post{} = post) do
    post
    |> Post.destroy_changeset()
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> change_post(post)
      %Ecto.Changeset{source: %Post{}}

  """
  def change_post(%Post{} = post) do
    Post.changeset(post, %{})
  end

  def user_name_reindex(old_name, new_name) do
    data = PostIndex.user_name_update_by_query(old_name, new_name)

    Elasticsearch.update_by_query(Post, data.query, data.set_replacements, data.replacements)
  end

  def reindex_post(%Post{} = post) do
    spawn(fn ->
      Post
      |> preload(^indexing_preloads())
      |> where(id: ^post.id)
      |> Repo.one()
      |> Elasticsearch.index_document(Post)
    end)

    post
  end

  def indexing_preloads do
    [:user, topic: :forum]
  end
end
