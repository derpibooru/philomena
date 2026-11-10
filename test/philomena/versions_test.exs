defmodule Philomena.VersionsTest do
  use Philomena.DataCase, async: true

  alias Philomena.Multi
  alias Philomena.Comments
  alias Philomena.Comments.CommentVersion
  alias Philomena.Posts
  alias Philomena.Posts.Post
  alias Philomena.Posts.PostVersion
  alias Philomena.Versions

  import Philomena.AttributionFixtures, only: [actor: 1]
  import Philomena.CommentsFixtures
  import Philomena.ForumsFixtures
  import Philomena.ImagesFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  defp update_post(post, actor, attrs) do
    post = Repo.preload(post, topic: :forum)
    Posts.update_post(actor, post.topic.forum.short_name, post.topic.slug, post.id, attrs)
  end

  defp post_versions(post) do
    PostVersion
    |> where(post_id: ^post.id)
    |> order_by(asc: :id)
    |> Repo.all()
  end

  defp comment_versions(comment) do
    CommentVersion
    |> where(comment_id: ^comment.id)
    |> order_by(asc: :id)
    |> Repo.all()
  end

  defp post_fixture_with_body(body) do
    forum = forum_fixture()
    author = confirmed_user_fixture()
    topic = topic_fixture(forum, author, %{"posts" => %{"0" => %{"body" => body}}})
    [post] = topic.posts
    {post, author}
  end

  describe "record_edit/5 for posts" do
    test "first edit creates an attributed initial row and edited snapshot" do
      {post, author} = post_fixture_with_body("Original body")
      editor = moderator_user_fixture()

      {:ok, _result} =
        update_post(post, actor(editor), %{
          "body" => "Edited body",
          "edit_reason" => "typo fix"
        })

      assert [initial, edit] = post_versions(post)
      assert initial.post_id == post.id
      assert initial.user_id == author.id
      assert initial.body == "Original body"
      assert initial.edit_reason == nil
      assert DateTime.compare(initial.created_at, post.created_at) == :eq

      assert edit.post_id == post.id
      assert edit.user_id == editor.id
      assert edit.body == "Edited body"
      assert edit.edit_reason == "typo fix"
    end

    test "later edits add one snapshot and same-second ids preserve their order" do
      {post, _author} = post_fixture_with_body("v0")
      editor = moderator_user_fixture()

      {:ok, post} =
        update_post(post, actor(editor), %{
          "body" => "v1",
          "edit_reason" => "r1"
        })

      {:ok, _result} =
        update_post(post, actor(editor), %{
          "body" => "v2",
          "edit_reason" => "r2"
        })

      assert [initial, first_edit, second_edit] = post_versions(post)
      assert initial.body == "v0"
      assert first_edit.body == "v1"
      assert second_edit.body == "v2"
      assert initial.id < first_edit.id
      assert first_edit.id < second_edit.id
    end

    test "a stale caller snapshots the locked row rather than stale unchanged fields" do
      {stale_post, _author} = post_fixture_with_body("v0")
      editor = moderator_user_fixture()

      assert {:ok, _result} =
               update_post(stale_post, actor(editor), %{
                 "body" => "v1",
                 "edit_reason" => "first reason"
               })

      assert {:ok, _result} =
               update_post(stale_post, actor(editor), %{"body" => "v2"})

      assert [_initial, _first_edit, second_edit] = post_versions(stale_post)
      assert second_edit.body == "v2"
      assert second_edit.edit_reason == "first reason"
      assert Repo.get!(Post, stale_post.id).edit_reason == second_edit.edit_reason
    end

    test "an update with unchanged body and edit reason creates no history" do
      {post, author} = post_fixture_with_body("same body")

      assert {:ok, %Post{}} =
               update_post(post, actor(author), %{
                 "body" => post.body,
                 "edit_reason" => post.edit_reason
               })

      assert post_versions(post) == []
    end

    test "the parent update and version rows roll back together" do
      {post, _author} = post_fixture_with_body("before")
      now = DateTime.utc_now(:second)

      result =
        Multi.new()
        |> Multi.put(:original_post, post)
        |> Multi.update(:post, Post.changeset(post, %{"body" => "after"}, now))
        |> Versions.record_edit(
          :version,
          :original_post,
          :post,
          actor(confirmed_user_fixture())
        )
        |> Multi.run(:forced_failure, fn _repo, _changes -> {:error, :forced_rollback} end)
        |> Multi.transact()

      assert {:error, :forced_failure, :forced_rollback, _changes} = result
      assert Repo.get!(Post, post.id).body == "before"
      assert post_versions(post) == []
    end
  end

  describe "record_edit/5 for comments" do
    test "first edit creates the initial row and attributed edited snapshot" do
      image = image_fixture()
      author = confirmed_user_fixture()
      editor = admin_user_fixture()
      comment = comment_fixture(image, author, %{"body" => "Original comment"})

      {:ok, _result} =
        Comments.update_comment(actor(editor), image.id, comment.id, %{
          "body" => "Edited comment",
          "edit_reason" => "clarify"
        })

      assert [initial, edit] = comment_versions(comment)
      assert initial.comment_id == comment.id
      assert initial.user_id == author.id
      assert initial.body == "Original comment"
      assert DateTime.compare(initial.created_at, comment.created_at) == :eq
      assert edit.user_id == editor.id
      assert edit.body == "Edited comment"
      assert edit.edit_reason == "clarify"
    end

    test "an update with unchanged content creates no history" do
      user = confirmed_user_fixture()
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "same"})

      assert {:ok, _comment} =
               Comments.update_comment(actor(user), image.id, comment.id, %{
                 "body" => comment.body,
                 "edit_reason" => comment.edit_reason
               })

      assert comment_versions(comment) == []
    end
  end

  describe "loaded-parent history services" do
    test "post history is newest-first and pairs previous bodies" do
      {post, _author} = post_fixture_with_body("v0")
      editor = moderator_user_fixture()

      {:ok, post} =
        update_post(post, actor(editor), %{
          "body" => "v1",
          "edit_reason" => "r1"
        })

      {:ok, _result} =
        update_post(post, actor(editor), %{
          "body" => "v2",
          "edit_reason" => "r2"
        })

      assert [newest, older] = Versions.for_post(post)
      assert {newest.body, newest.previous_body, newest.edit_reason} == {"v2", "v1", "r2"}
      assert newest.parent.id == post.id
      assert {older.body, older.previous_body, older.edit_reason} == {"v1", "v0", "r1"}
      refute Enum.any?(Versions.for_post(post), &(&1.body == "v0"))
    end

    test "comment history follows the same pairing rules" do
      user = confirmed_user_fixture()
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "c0"})

      {:ok, {_image, comment}} =
        Comments.update_comment(actor(user), image.id, comment.id, %{"body" => "c1"})

      assert [%CommentVersion{} = version] = Versions.for_comment(comment)
      assert version.body == "c1"
      assert version.previous_body == "c0"
      assert version.parent.id == comment.id
    end

    test "never-edited loaded parents have no history and ids are not accepted" do
      {post, _author} = post_fixture_with_body("unchanged")
      image = image_fixture()
      comment = comment_fixture(image)

      assert Versions.for_post(post) == []
      assert Versions.for_comment(comment) == []

      assert_raise FunctionClauseError, fn -> Versions.for_post(post.id) end
      assert_raise FunctionClauseError, fn -> Versions.for_comment(comment.id) end
    end
  end
end
