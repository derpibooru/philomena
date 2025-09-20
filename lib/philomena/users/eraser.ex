defmodule Philomena.Users.Eraser do
  import Ecto.Query
  alias Philomena.Repo

  alias Philomena.Bans
  alias Philomena.Comments.Comment
  alias Philomena.Comments
  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries
  alias Philomena.Posts.Post
  alias Philomena.Posts
  alias Philomena.Topics.Topic
  alias Philomena.Topics
  alias Philomena.Images
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.Reports
  alias Philomena.Users

  @reason "Site abuse"
  @wipe_ip %Postgrex.INET{address: {127, 0, 1, 1}, netmask: 32}
  @wipe_fp "ffff"

  def erase_permanently!(user, moderator) do
    # Erase avatar
    {:ok, user} = Users.remove_avatar(user)

    # Erase "about me" and personal title
    {:ok, user} = Users.update_description(user, %{description: "", personal_title: ""})

    # Delete all forum posts
    Post
    |> where(user_id: ^user.id)
    |> Repo.all()
    |> Enum.each(fn post ->
      {:ok, post} = Posts.hide_post(post, %{deletion_reason: @reason}, moderator)
      {:ok, _post} = Posts.destroy_post(post)
    end)

    # Delete all comments
    Comment
    |> where(user_id: ^user.id)
    |> Repo.all()
    |> Enum.each(fn comment ->
      {:ok, comment} = Comments.hide_comment(comment, %{deletion_reason: @reason}, moderator)
      {:ok, _comment} = Comments.destroy_comment(comment)
    end)

    # Delete all galleries
    Gallery
    |> where(creator_id: ^user.id)
    |> Repo.all()
    |> Enum.each(fn gallery ->
      {:ok, _gallery} = Galleries.delete_gallery(gallery)
    end)

    # Delete all posted topics
    Topic
    |> where(user_id: ^user.id)
    |> Repo.all()
    |> Enum.each(fn topic ->
      {:ok, _topic} = Topics.hide_topic(topic, @reason, moderator)
    end)

    # Revert all source changes
    SourceChange
    |> where(user_id: ^user.id)
    |> order_by(desc: :created_at)
    |> preload(:image)
    |> Repo.all()
    |> Enum.each(fn source_change ->
      if source_change.added do
        revert_added_source_change(source_change, user)
      else
        revert_removed_source_change(source_change, user)
      end
    end)

    # Delete all source changes
    SourceChange
    |> where(user_id: ^user.id)
    |> Repo.delete_all()

    # Ban the user
    {:ok, _ban} =
      Bans.create_user(
        moderator,
        %{
          "user_id" => user.id,
          "reason" => @reason,
          "valid_until" => "permanent"
        }
      )

    # Close all reports against the user
    {:ok, _} = Reports.close_reports({"User", user.id}, moderator)

    # We succeeded
    :ok
  end

  defp revert_removed_source_change(source_change, user) do
    old_sources = %{}
    new_sources = %{"0" => %{"source" => source_change.source_url}}

    revert_source_change(source_change, user, old_sources, new_sources)
  end

  defp revert_added_source_change(source_change, user) do
    old_sources = %{"0" => %{"source" => source_change.source_url}}
    new_sources = %{}

    revert_source_change(source_change, user, old_sources, new_sources)
  end

  defp revert_source_change(source_change, user, old_sources, new_sources) do
    attrs = %{"old_sources" => old_sources, "sources" => new_sources}

    attribution = [
      user: user,
      ip: @wipe_ip,
      fingerprint: @wipe_fp
    ]

    {:ok, _} = Images.update_sources(source_change.image, attribution, attrs)
  end
end
