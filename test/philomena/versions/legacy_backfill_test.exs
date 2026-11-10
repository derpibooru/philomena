defmodule Philomena.Versions.LegacyBackfillTest do
  @moduledoc """
  Tests for `Philomena.Versions.LegacyBackfill.run!/0`, which converts the
  paper_trail-shaped `versions_legacy` table (pre-edit snapshots in a JSON
  `object` column) into the normalized after-edit `post_versions` and
  `comment_versions` tables.

  Legacy rows are seeded with raw SQL directly against `versions_legacy`. The
  ExUnit SQL sandbox wraps each test in a transaction, and `run!/0` executes
  its statements through `Repo.query!` on that same sandboxed connection, so
  everything rolls back at the end of the test.
  """

  use Philomena.DataCase, async: true

  import Philomena.AttributionFixtures, only: [actor: 1]
  import Philomena.CommentsFixtures
  import Philomena.ForumsFixtures
  import Philomena.ImagesFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Comments.Comment
  alias Philomena.Comments.CommentVersion
  alias Philomena.Posts
  alias Philomena.Posts.Post
  alias Philomena.Posts.PostVersion
  alias Philomena.Versions
  alias Philomena.Versions.LegacyBackfill

  defp update_post(post, actor, attrs) do
    post = Repo.preload(post, topic: :forum)
    Posts.update_post(actor, post.topic.forum.short_name, post.topic.slug, post.id, attrs)
  end

  # Insert a paper_trail-shaped row into versions_legacy. `object` is a JSON
  # string (or nil for a 'create' event), `whodunnit` is a string id (or nil),
  # and `created_at` is a NaiveDateTime.
  defp seed_legacy(item_type, item_id, event, whodunnit, object, created_at) do
    Repo.query!(
      """
      INSERT INTO versions_legacy (item_type, item_id, event, whodunnit, object, created_at)
      VALUES ($1, $2, $3, $4, $5, $6)
      """,
      [item_type, item_id, event, whodunnit, object, created_at]
    )
  end

  defp set_live(schema, id, body, edit_reason, created_at) do
    {1, _} =
      Repo.update_all(from(r in schema, where: r.id == ^id),
        set: [body: body, edit_reason: edit_reason, created_at: created_at]
      )
  end

  # Version rows in chain order (initial row first), reduced to the fields the
  # conversion produces.
  defp post_rows(post) do
    PostVersion
    |> where(post_id: ^post.id)
    |> order_by(asc: :created_at, asc: :id)
    |> Repo.all()
    |> Enum.map(&{&1.body, &1.edit_reason, &1.user_id})
  end

  defp comment_rows(comment) do
    CommentVersion
    |> where(comment_id: ^comment.id)
    |> order_by(asc: :created_at, asc: :id)
    |> Repo.all()
    |> Enum.map(&{&1.body, &1.edit_reason, &1.user_id})
  end

  defp object(body, edit_reason) do
    Jason.encode!(%{"body" => body, "edit_reason" => edit_reason})
  end

  defp seed_post do
    forum = forum_fixture()
    author = confirmed_user_fixture()
    topic = topic_fixture(forum, author, %{"posts" => %{"0" => %{"body" => "seed body"}}})
    [post] = topic.posts
    {post, author}
  end

  describe "run!/0 conversion of post chains" do
    test "a 3-edit chain becomes a synthesized initial row plus 3 shifted rows" do
      {post, author} = seed_post()
      u1 = confirmed_user_fixture()
      u2 = confirmed_user_fixture()
      u3 = confirmed_user_fixture()

      set_live(Post, post.id, "body v3 live", "live reason", ~U[2019-06-01 00:00:00Z])

      # Each legacy 'update' row holds the PRE-edit state in its object.
      seed_legacy(
        "Post",
        post.id,
        "update",
        to_string(u1.id),
        object("body v0", "reason 0"),
        ~N[2020-01-01 00:00:01]
      )

      seed_legacy(
        "Post",
        post.id,
        "update",
        to_string(u2.id),
        object("body v1", "reason 1"),
        ~N[2020-01-01 00:00:02]
      )

      seed_legacy(
        "Post",
        post.id,
        "update",
        to_string(u3.id),
        object("body v2", "reason 2"),
        ~N[2020-01-01 00:00:03]
      )

      assert :ok = LegacyBackfill.run!()

      # Four rows: the synthesized initial (author, oldest object body, nil
      # reason), then each legacy row shifted forward to take the next row's
      # object body - the newest taking the live post's current state. Each
      # shifted row keeps its own legacy whodunnit.
      assert post_rows(post) == [
               {"body v0", nil, author.id},
               {"body v1", "reason 1", u1.id},
               {"body v2", "reason 2", u2.id},
               {"body v3 live", "live reason", u3.id}
             ]
    end

    test "a 'create' event row supplies the initial state, so no extra initial row is synthesized" do
      {post, _author} = seed_post()
      u1 = confirmed_user_fixture()
      u2 = confirmed_user_fixture()

      set_live(Post, post.id, "live body", "live reason", ~U[2019-06-01 00:00:00Z])

      # A Rails-style 'create' row has a NULL object.
      seed_legacy("Post", post.id, "create", to_string(u1.id), nil, ~N[2020-01-01 00:00:01])

      seed_legacy(
        "Post",
        post.id,
        "update",
        to_string(u2.id),
        object("body v0", "reason 0"),
        ~N[2020-01-01 00:00:02]
      )

      assert :ok = LegacyBackfill.run!()

      # Exactly two rows and no synthesized initial: the create row shifts up to
      # become the initial state (body v0), and the update row takes the live state.
      assert post_rows(post) == [
               {"body v0", "reason 0", u1.id},
               {"live body", "live reason", u2.id}
             ]
    end

    test "a null JSON body in a middle row shifts to an empty string, not the parent body" do
      {post, author} = seed_post()
      u1 = confirmed_user_fixture()
      u2 = confirmed_user_fixture()
      u3 = confirmed_user_fixture()

      set_live(Post, post.id, "live body", "live reason", ~U[2019-06-01 00:00:00Z])

      seed_legacy(
        "Post",
        post.id,
        "update",
        to_string(u1.id),
        object("b0", "e0"),
        ~N[2020-01-01 00:00:01]
      )

      # Middle row's object body is JSON null.
      seed_legacy(
        "Post",
        post.id,
        "update",
        to_string(u2.id),
        ~s({"body":null,"edit_reason":"e1"}),
        ~N[2020-01-01 00:00:02]
      )

      seed_legacy(
        "Post",
        post.id,
        "update",
        to_string(u3.id),
        object("b2", "e2"),
        ~N[2020-01-01 00:00:03]
      )

      assert :ok = LegacyBackfill.run!()

      # The first update row shifts to the middle row's null body → "" (the
      # LEAD is present but its body is null), rather than falling through to
      # the live parent body.
      assert post_rows(post) == [
               {"b0", nil, author.id},
               {"", "e1", u1.id},
               {"b2", "e2", u2.id},
               {"live body", "live reason", u3.id}
             ]
    end
  end

  describe "run!/0 whodunnit resolution" do
    test "non-numeric, dangling, and null whodunnit all resolve to a null user_id" do
      {post, author} = seed_post()

      set_live(Post, post.id, "live body", "live reason", ~U[2019-06-01 00:00:00Z])

      # Non-numeric whodunnit fails the '^[0-9]+$' guard, so the ::bigint cast is
      # never applied (a CASE keeps it out of the join predicate) and no user matches.
      seed_legacy(
        "Post",
        post.id,
        "update",
        "admin:zebra",
        object("b0", "e0"),
        ~N[2020-01-01 00:00:01]
      )

      # Numeric but points at no user.
      seed_legacy(
        "Post",
        post.id,
        "update",
        "999999999",
        object("b1", "e1"),
        ~N[2020-01-01 00:00:02]
      )

      # Null whodunnit.
      seed_legacy("Post", post.id, "update", nil, object("b2", "e2"), ~N[2020-01-01 00:00:03])

      assert :ok = LegacyBackfill.run!()

      user_ids =
        PostVersion
        |> where(post_id: ^post.id)
        |> order_by(asc: :created_at, asc: :id)
        |> Repo.all()
        |> Enum.map(& &1.user_id)

      # Initial row keeps the post's author; every shifted row loses its
      # unresolvable whodunnit to NULL.
      assert user_ids == [author.id, nil, nil, nil]
    end
  end

  describe "run!/0 filtering of rows it must not convert" do
    test "a legacy row whose item no longer exists is not converted" do
      # item_id points at no post.
      seed_legacy(
        "Post",
        987_654_321,
        "update",
        nil,
        object("orphan", "reason"),
        ~N[2020-01-01 00:00:01]
      )

      assert :ok = LegacyBackfill.run!()

      assert Repo.aggregate(PostVersion, :count) == 0
      assert Repo.aggregate(CommentVersion, :count) == 0
    end

    test "a foreign item_type (Image) converts nothing and is left in place" do
      image = image_fixture()

      seed_legacy(
        "Image",
        image.id,
        "update",
        nil,
        object("ignored", "reason"),
        ~N[2020-01-01 00:00:01]
      )

      assert :ok = LegacyBackfill.run!()

      assert Repo.aggregate(PostVersion, :count) == 0
      assert Repo.aggregate(CommentVersion, :count) == 0

      %{rows: [[count]]} =
        Repo.query!("SELECT COUNT(*) FROM versions_legacy WHERE item_type = 'Image'")

      assert count == 1
    end
  end

  describe "run!/0 conversion of comment chains" do
    test "a comment chain becomes comment_versions rows" do
      image = image_fixture()
      author = confirmed_user_fixture()
      u1 = confirmed_user_fixture()
      u2 = confirmed_user_fixture()

      comment = comment_fixture(image, author, %{"body" => "seed comment"})
      set_live(Comment, comment.id, "live comment body", "live reason", ~U[2019-06-01 00:00:00Z])

      seed_legacy(
        "Comment",
        comment.id,
        "update",
        to_string(u1.id),
        object("cb0", "cr0"),
        ~N[2020-01-01 00:00:01]
      )

      seed_legacy(
        "Comment",
        comment.id,
        "update",
        to_string(u2.id),
        object("cb1", "cr1"),
        ~N[2020-01-01 00:00:02]
      )

      assert :ok = LegacyBackfill.run!()

      assert comment_rows(comment) == [
               {"cb0", nil, author.id},
               {"cb1", "cr1", u1.id},
               {"live comment body", "live reason", u2.id}
             ]
    end
  end

  describe "run!/0 guard" do
    test "raises when a target table already contains rows" do
      forum = forum_fixture()
      author = confirmed_user_fixture()
      topic = topic_fixture(forum, author, %{"posts" => %{"0" => %{"body" => "original"}}})
      [post] = topic.posts

      # A real edit populates post_versions through the normal path.
      {:ok, _} =
        update_post(post, actor(author), %{
          "body" => "edited",
          "edit_reason" => "x"
        })

      assert Repo.aggregate(PostVersion, :count) > 0

      assert_raise RuntimeError, ~r/post_versions already contains/, fn ->
        LegacyBackfill.run!()
      end
    end
  end

  describe "for_post/1 after backfill" do
    test "reproduces the legacy edit history as display entries" do
      {post, _author} = seed_post()
      u1 = confirmed_user_fixture()
      u2 = confirmed_user_fixture()
      u3 = confirmed_user_fixture()

      set_live(Post, post.id, "body v3 live", "live reason", ~U[2019-06-01 00:00:00Z])

      seed_legacy(
        "Post",
        post.id,
        "update",
        to_string(u1.id),
        object("body v0", "reason 0"),
        ~N[2020-01-01 00:00:01]
      )

      seed_legacy(
        "Post",
        post.id,
        "update",
        to_string(u2.id),
        object("body v1", "reason 1"),
        ~N[2020-01-01 00:00:02]
      )

      seed_legacy(
        "Post",
        post.id,
        "update",
        to_string(u3.id),
        object("body v2", "reason 2"),
        ~N[2020-01-01 00:00:03]
      )

      assert :ok = LegacyBackfill.run!()

      entries =
        Versions.for_post(post)
        |> Enum.map(&{&1.body, &1.previous_body, &1.edit_reason})

      # Newest-first, each entry pairs an after-edit body with the next-older
      # body; the synthesized initial row (body v0) is only a diff base.
      assert entries == [
               {"body v3 live", "body v2", "live reason"},
               {"body v2", "body v1", "reason 2"},
               {"body v1", "body v0", "reason 1"}
             ]
    end
  end
end
