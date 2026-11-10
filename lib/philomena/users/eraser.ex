defmodule Philomena.Users.Eraser do
  import Ecto.Query
  alias Philomena.Repo

  alias Philomena.Attribution.Actor
  alias Philomena.Bans
  alias Philomena.Comments.Comment
  alias Philomena.Comments
  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries
  alias Philomena.Posts.Post
  alias Philomena.Posts
  alias Philomena.Topics.Topic
  alias Philomena.Topics
  alias Philomena.Reports.Report
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.SourceChanges
  alias Philomena.Reports
  alias Philomena.Users

  @reason "Site abuse"
  @wipe_ip %Postgrex.INET{address: {127, 0, 1, 1}, netmask: 32}
  @wipe_fp "ffff"

  def erase_permanently!(user, moderator) do
    system_actor = system_actor(moderator)

    # Erase avatar
    {:ok, user} = Users.delete_user_avatar(system_actor, user.slug)

    # Erase "about me" and personal title
    {:ok, user} =
      Users.update_profile_description(system_actor, user.slug, %{
        description: "",
        personal_title: ""
      })

    # Delete all forum posts
    Post
    |> where(user_id: ^user.id)
    |> preload(topic: :forum)
    |> Repo.all()
    |> Enum.each(fn post ->
      if not post.destroyed_content do
        {:ok, _post} =
          Posts.create_post_hide(
            system_actor,
            post.topic.forum.short_name,
            post.topic.slug,
            post.id,
            %{deletion_reason: @reason}
          )

        {:ok, _post} =
          Posts.create_post_delete(
            system_actor,
            post.topic.forum.short_name,
            post.topic.slug,
            post.id
          )
      end
    end)

    # Delete all comments
    Comment
    |> where(user_id: ^user.id)
    |> Repo.all()
    |> Enum.each(fn comment ->
      if not comment.destroyed_content do
        {:ok, _comment} =
          Comments.create_comment_hide(
            system_actor,
            comment.image_id,
            comment.id,
            %{deletion_reason: @reason}
          )

        {:ok, _comment} =
          Comments.create_comment_delete(system_actor, comment.image_id, comment.id)
      end
    end)

    # Delete all galleries
    Gallery
    |> where(user_id: ^user.id)
    |> select([gallery], gallery.id)
    |> Repo.all()
    |> Enum.each(fn gallery_id ->
      {:ok, _gallery} = Galleries.delete_gallery(system_actor, gallery_id)
    end)

    # Delete all posted topics
    Topic
    |> where(user_id: ^user.id)
    |> preload(:forum)
    |> Repo.all()
    |> Enum.each(fn topic ->
      if not topic.hidden_from_users do
        {:ok, _topic} =
          Topics.create_topic_hide(
            system_actor,
            topic.forum.short_name,
            topic.slug,
            %{deletion_reason: @reason}
          )
      end
    end)

    # Revert all source changes
    SourceChange
    |> where(user_id: ^user.id)
    |> order_by(desc: :created_at)
    |> Repo.all()
    |> Enum.each(fn source_change ->
      {:ok, _change} =
        SourceChanges.erase_source_change(system_actor, source_change.id)
    end)

    # Ban the user
    {:ok, _ban} =
      Bans.create_user_ban(
        system_actor,
        user.id,
        %{
          reason: @reason,
          valid_until: "permanent"
        }
      )

    # Close all reports against the user
    Report
    |> where(reported_user_id: ^user.id, open: true)
    |> select([report], report.id)
    |> Repo.all()
    |> Enum.each(fn report_id ->
      {:ok, _report} = Reports.create_report_close(system_actor, report_id)
    end)

    # We succeeded
    :ok
  end

  defp system_actor(moderator) do
    %Actor{user: moderator, ip: @wipe_ip, fingerprint: @wipe_fp}
  end
end
