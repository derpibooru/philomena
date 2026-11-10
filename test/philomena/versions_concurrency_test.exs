defmodule Philomena.VersionsConcurrencyTest do
  use Philomena.ConcurrentDataCase

  alias Ecto.Adapters.SQL.Sandbox
  alias Philomena.Posts
  alias Philomena.Posts.Post
  alias Philomena.Posts.PostVersion
  alias Philomena.Repo
  alias Philomena.Versions

  import Ecto.Query
  import Philomena.AttributionFixtures, only: [actor: 1]
  import Philomena.ForumsFixtures
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

  defp post_fixture_with_body(body) do
    forum = forum_fixture()
    author = confirmed_user_fixture()
    topic = topic_fixture(forum, author, %{"posts" => %{"0" => %{"body" => body}}})
    [post] = topic.posts
    {post, author}
  end

  test "concurrent first edits create one initial row and ordered snapshots" do
    {post, _author} = post_fixture_with_body("v0")
    editor = moderator_user_fixture()
    parent = self()

    tasks =
      for body <- ["v1", "v2"] do
        task =
          Task.async(fn ->
            original = Repo.get!(Post, post.id)
            send(parent, {:ready, self()})

            receive do
              :edit -> update_post(original, actor(editor), %{"body" => body})
            end
          end)

        Sandbox.allow(Repo, parent, task.pid)
        task
      end

    task_pids =
      for _ <- tasks do
        assert_receive {:ready, task_pid}
        task_pid
      end

    Enum.each(task_pids, &send(&1, :edit))
    assert Enum.all?(tasks, &match?({:ok, _}, Task.await(&1, 5_000)))

    assert [initial, first_edit, second_edit] = post_versions(post)
    assert initial.body == "v0"
    assert Enum.sort([first_edit.body, second_edit.body]) == ["v1", "v2"]
    assert first_edit.id < second_edit.id

    assert [newest, older] = Versions.for_post(post)
    assert newest.body == second_edit.body
    assert newest.previous_body == first_edit.body
    assert older.body == first_edit.body
    assert older.previous_body == "v0"
  end
end
