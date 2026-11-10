defmodule Philomena.Versions do
  @moduledoc """
  Edit history for posts and comments.

  History reads accept loaded parents only. Authorization remains in
  `Philomena.Posts` and `Philomena.Comments`. History writes compose into the
  same `Ecto.Multi` as the parent update, so neither change can commit alone.

  Version rows are after-edit snapshots. On the first meaningful edit, an
  initial row captures the parent's original state and attribution before the
  edited snapshot is inserted. An update that changes neither the body nor the
  edit reason creates no history rows.
  """

  import Ecto.Query, warn: false

  alias Philomena.Multi
  alias Philomena.Attribution.Actor
  alias Philomena.Comments.Comment
  alias Philomena.Comments.CommentVersion
  alias Philomena.Posts.Post
  alias Philomena.Posts.PostVersion
  alias Philomena.Repo
  alias Philomena.Users.User

  defp meaningful_edit?(original, updated) do
    original.body != updated.body or original.edit_reason != updated.edit_reason
  end

  defp maybe_insert_initial(repo, schema, foreign_key, original) do
    if repo.exists?(where(schema, [version], field(version, ^foreign_key) == ^original.id)) do
      :ok
    else
      schema
      |> struct([
        {foreign_key, original.id},
        {:user_id, original.user_id},
        {:body, original.body},
        {:created_at, original.created_at}
      ])
      |> repo.insert()
      |> case do
        {:ok, _version} -> :ok
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  defp insert_snapshot(repo, schema, foreign_key, updated, editor_id) do
    schema
    |> struct([
      {foreign_key, updated.id},
      {:user_id, editor_id},
      {:body, updated.body},
      {:edit_reason, updated.edit_reason}
    ])
    |> repo.insert()
  end

  defp persist_edit(repo, schema, foreign_key, original, updated, %User{} = editor) do
    if meaningful_edit?(original, updated) do
      with :ok <- maybe_insert_initial(repo, schema, foreign_key, original) do
        insert_snapshot(repo, schema, foreign_key, updated, editor.id)
      end
    else
      {:ok, nil}
    end
  end

  defp load_versions(schema, foreign_key, parent) do
    schema
    |> where([version], field(version, ^foreign_key) == ^parent.id)
    |> order_by(desc: :created_at, desc: :id)
    |> limit(26)
    |> preload(user: [awards: :badge])
    |> Repo.all()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [version, previous] ->
      %{version | parent: parent, previous_body: previous.body}
    end)
  end

  @doc """
  Loads version history for an already authorized post.

  Results are newest first, limited to 25, and carry their parent and previous
  body for rendering a diff. A never-edited post returns `[]`.

  ## Examples

      iex> for_post(authorized_post)
      [%PostVersion{}, ...]

  """
  @spec for_post(Post.t()) :: [PostVersion.t()]
  def for_post(%Post{} = post), do: load_versions(PostVersion, :post_id, post)

  @doc """
  Loads version history for an already authorized comment.

  Results are newest first, limited to 25, and carry their parent and previous
  body for rendering a diff. A never-edited comment returns `[]`.

  ## Examples

      iex> for_comment(authorized_comment)
      [%CommentVersion{}, ...]

  """
  @spec for_comment(Comment.t()) :: [CommentVersion.t()]
  def for_comment(%Comment{} = comment),
    do: load_versions(CommentVersion, :comment_id, comment)

  @doc """
  Adds post or comment version history to an owning update Multi.

  `original_step` and `updated_step` must name prior steps returning the loaded
  parent before and after its update. Both must have the same supported parent
  type. The actor's user attributes the edited snapshot. This step inserts the
  initial and edited snapshots atomically with the parent update, or returns
  `nil` without inserting history when body and edit reason are unchanged.

  The parent's update lock serializes concurrent edits. Same-second snapshots
  are ordered by their increasing database ids.

  ## Examples

      iex> record_edit(multi, :version, :original, :updated, actor)
      %Ecto.Multi{}

  """
  @spec record_edit(
          multi :: Multi.t(),
          name :: Multi.name(),
          original_step :: Multi.name(),
          updated_step :: Multi.name(),
          actor :: Actor.t()
        ) :: Multi.t()
  def record_edit(
        %Multi{} = multi,
        name,
        original_step,
        updated_step,
        %Actor{user: %User{} = editor}
      ) do
    Multi.run(multi, name, fn repo, changes ->
      original = Map.fetch!(changes, original_step)
      updated = Map.fetch!(changes, updated_step)

      case {original, updated} do
        {%Post{}, %Post{}} ->
          persist_edit(repo, PostVersion, :post_id, original, updated, editor)

        {%Comment{}, %Comment{}} ->
          persist_edit(repo, CommentVersion, :comment_id, original, updated, editor)

        _other ->
          {:error, :invalid_parent}
      end
    end)
  end
end
