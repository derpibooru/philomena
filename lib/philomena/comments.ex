defmodule Philomena.Comments do
  @moduledoc """
  The Comments context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Elasticsearch
  alias Philomena.Reports.Report
  alias Philomena.UserStatistics
  alias Philomena.Comments.Comment
  alias Philomena.Comments.ElasticsearchIndex, as: CommentIndex
  alias Philomena.IndexWorker
  alias Philomena.Images.Image
  alias Philomena.Images
  alias Philomena.Notifications
  alias Philomena.NotificationWorker
  alias Philomena.Versions
  alias Philomena.Reports
  alias Philomena.Users.User
  alias Philomena.Games.{Player, Team}

  @doc """
  Gets a single comment.

  Raises `Ecto.NoResultsError` if the Comment does not exist.

  ## Examples

      iex> get_comment!(123)
      %Comment{}

      iex> get_comment!(456)
      ** (Ecto.NoResultsError)

  """
  def get_comment!(id), do: Repo.get!(Comment, id)

  @doc """
  Creates a comment.

  ## Examples

      iex> create_comment(%{field: value})
      {:ok, %Comment{}}

      iex> create_comment(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_comment(image, attribution, params \\ %{}) do
    comment =
      Ecto.build_assoc(image, :comments)
      |> Comment.creation_changeset(params, attribution)

    image_query =
      Image
      |> where(id: ^image.id)

    Multi.new()
    |> Multi.insert(:comment, comment)
    |> Multi.update_all(:image, image_query, inc: [comments_count: 1])
    |> maybe_create_subscription_on_reply(image, attribution[:user])
    |> Repo.transaction()
  end

  defp maybe_create_subscription_on_reply(multi, image, %User{watch_on_reply: true} = user) do
    multi
    |> Multi.run(:subscribe, fn _repo, _changes ->
      Images.create_subscription(image, user)
    end)
  end

  defp maybe_create_subscription_on_reply(multi, _image, _user) do
    multi
  end

  def notify_comment(comment) do
    Exq.enqueue(Exq, "notifications", NotificationWorker, ["Comments", comment.id])
  end

  def perform_notify(comment_id) do
    comment = get_comment!(comment_id)

    image =
      comment
      |> Repo.preload(:image)
      |> Map.fetch!(:image)

    subscriptions =
      image
      |> Repo.preload(:subscriptions)
      |> Map.fetch!(:subscriptions)

    Notifications.notify(
      comment,
      subscriptions,
      %{
        actor_id: image.id,
        actor_type: "Image",
        actor_child_id: comment.id,
        actor_child_type: "Comment",
        action: "commented on"
      }
    )
  end

  @doc """
  Updates a comment.

  ## Examples

      iex> update_comment(comment, %{field: new_value})
      {:ok, %Comment{}}

      iex> update_comment(comment, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_comment(%Comment{} = comment, editor, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    current_body = comment.body
    current_reason = comment.edit_reason

    comment_changes = Comment.changeset(comment, attrs, now)

    Multi.new()
    |> Multi.update(:comment, comment_changes)
    |> Multi.run(:version, fn _repo, _changes ->
      Versions.create_version("Comment", comment.id, editor.id, %{
        "body" => current_body,
        "edit_reason" => current_reason
      })
    end)
    |> Repo.transaction()
  end

  @doc """
  Deletes a Comment.

  ## Examples

      iex> delete_comment(comment)
      {:ok, %Comment{}}

      iex> delete_comment(comment)
      {:error, %Ecto.Changeset{}}

  """
  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  def hide_comment(%Comment{} = comment, attrs, user) do
    reports =
      Report
      |> where(reportable_type: "Comment", reportable_id: ^comment.id)
      |> select([r], r.id)
      |> update(set: [open: false, state: "closed", admin_id: ^user.id])

    original_comment = Repo.preload(comment, :user)
    comment = Comment.hide_changeset(comment, attrs, user)

    Multi.new()
    |> Multi.update(:comment, comment)
    |> Multi.update_all(:reports, reports, [])
    |> maybe_remove_points_for_comment(original_comment.user)
    |> Repo.transaction()
    |> case do
      {:ok, %{comment: comment, reports: {_count, reports}}} ->
        Reports.reindex_reports(reports)
        reindex_comment(comment)

        {:ok, comment}

      error ->
        error
    end
  end

  defp maybe_remove_points_for_comment(multi, nil), do: multi

  defp maybe_remove_points_for_comment(multi, user) do
    user = Repo.preload(user, :game_profiles)

    case user do
      %User{game_profiles: [profile | _]} ->
        profile_query =
          Player
          |> where(user_id: ^user.id)

        team_query =
          Team
          |> where(id: ^profile.team_id)

        multi
        |> Multi.run(:increment_points, fn repo, _changes ->
          repo.update_all(profile_query, inc: [points: -min(profile.points, 2)])
          repo.update_all(team_query, inc: [points: -min(profile.points, 2)])
          {:ok, 0}
        end)

      _ ->
        multi
    end
  end

  def unhide_comment(%Comment{} = comment) do
    comment
    |> Comment.unhide_changeset()
    |> Repo.update()
    |> case do
      {:ok, comment} ->
        reindex_comment(comment)

        {:ok, comment}

      error ->
        error
    end
  end

  def destroy_comment(%Comment{} = comment) do
    comment
    |> Comment.destroy_changeset()
    |> Repo.update()
  end

  def approve_comment(%Comment{} = comment, user) do
    reports =
      Report
      |> where(reportable_type: "Comment", reportable_id: ^comment.id)
      |> select([r], r.id)
      |> update(set: [open: false, state: "closed", admin_id: ^user.id])

    comment = Comment.approve_changeset(comment)

    Multi.new()
    |> Multi.update(:comment, comment)
    |> Multi.update_all(:reports, reports, [])
    |> Repo.transaction()
    |> case do
      {:ok, %{comment: comment, reports: {_count, reports}}} ->
        notify_comment(comment)
        UserStatistics.inc_stat(comment.user, :comments_posted)
        Reports.reindex_reports(reports)
        reindex_comment(comment)

        {:ok, comment}

      error ->
        error
    end
  end

  def report_non_approved(%Comment{approved: true}), do: false

  def report_non_approved(comment) do
    Reports.create_system_report(
      comment.id,
      "Comment",
      "Approval",
      "Comment contains externally-embedded images and has been flagged for review."
    )
  end

  def migrate_comments(image, duplicate_of_image) do
    {count, nil} =
      Comment
      |> where(image_id: ^image.id)
      |> Repo.update_all(set: [image_id: duplicate_of_image.id])

    Image
    |> where(id: ^duplicate_of_image.id)
    |> Repo.update_all(inc: [comments_count: count])

    reindex_comments(duplicate_of_image)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking comment changes.

  ## Examples

      iex> change_comment(comment)
      %Ecto.Changeset{source: %Comment{}}

  """
  def change_comment(%Comment{} = comment) do
    Comment.changeset(comment, %{})
  end

  def user_name_reindex(old_name, new_name) do
    data = CommentIndex.user_name_update_by_query(old_name, new_name)

    Elasticsearch.update_by_query(Comment, data.query, data.set_replacements, data.replacements)
  end

  def reindex_comment(%Comment{} = comment) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Comments", "id", [comment.id]])

    comment
  end

  def reindex_comments(image) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Comments", "image_id", [image.id]])

    image
  end

  def indexing_preloads do
    [:user, image: :tags]
  end

  def perform_reindex(column, condition) do
    Comment
    |> preload(^indexing_preloads())
    |> where([c], field(c, ^column) in ^condition)
    |> Elasticsearch.reindex(Comment)
  end
end
