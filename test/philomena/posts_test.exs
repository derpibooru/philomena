defmodule Philomena.PostsTest do
  @moduledoc """
  Context-level tests for the actor-first `Philomena.Posts` API.

  These pin the authorization matrix (anonymous/user/moderator), the two
  global error shapes routed through the id guard, and the moderation log
  entry - type string, body, and subject path byte-for-byte - that
  `approve_post/2`, `hide_post/3`, and `unhide_post/2` write on success. The
  corresponding controller characterization tests pin the HTTP behavior on top
  of these results.
  """

  use Philomena.DataCase, async: true

  import Ecto.Query
  import Philomena.AttributionFixtures
  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.RulesFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Posts
  alias Philomena.Posts.Post
  alias Philomena.Posts.PostVersion
  alias Philomena.Reports.Report
  alias Philomena.Forums
  alias Philomena.Forums.Forum
  alias Philomena.Repo
  alias Philomena.Topics.Topic
  alias Philomena.Users.User

  # A truthy ban value in the shape production passes (the result of
  # Philomena.Bans.find/3); only its presence matters to the write-access and
  # not-banned checks the report loaders run first.
  @ban %{
    reason: "Rule #0",
    valid_until: ~U[3000-01-01 00:00:00Z],
    generated_ban_id: "U123456",
    type: "User"
  }

  setup do
    forum = forum_fixture()
    topic = topic_fixture(forum)

    %{forum: forum, topic: topic}
  end

  # A post authored by a fresh (untrusted) user containing an external link is
  # not auto-approved on creation (see Philomena.Schema.Approval); returns the
  # post together with its author so the posts_count bump can be checked.
  defp unapproved_post(topic) do
    approval_rule!()
    author = confirmed_user_fixture()

    post =
      post_fixture(topic, author, %{
        "body" => "check this out https://spam.example/"
      })

    refute post.approved
    {post, author}
  end

  defp approval_rule! do
    rule_fixture()
    |> Ecto.Changeset.change(name: "Approval")
    |> Repo.update!()
  end

  defp no_moderation_logs! do
    assert Repo.aggregate(ModerationLog, :count) == 0
  end

  defp route_parent(post_id) do
    post =
      case Philomena.IntegerId.parse(post_id) do
        {:ok, id} -> Repo.get(Post, id)
        :error -> nil
      end

    case post && Repo.preload(post, topic: :forum) do
      %Post{topic: topic} ->
        {topic.forum.short_name, topic.slug}

      nil ->
        forum = forum_fixture()
        topic = topic_fixture(forum)
        {forum.short_name, topic.slug}
    end
  end

  defp approve_post(actor, post_id) do
    {forum_slug, topic_slug} = route_parent(post_id)
    Posts.create_post_approve(actor, forum_slug, topic_slug, post_id)
  end

  defp hide_post(actor, post_id, attrs) do
    {forum_slug, topic_slug} = route_parent(post_id)
    Posts.create_post_hide(actor, forum_slug, topic_slug, post_id, attrs)
  end

  defp unhide_post(actor, post_id) do
    {forum_slug, topic_slug} = route_parent(post_id)
    Posts.delete_post_hide(actor, forum_slug, topic_slug, post_id)
  end

  defp destroy_post(actor, post_id) do
    {forum_slug, topic_slug} = route_parent(post_id)
    Posts.create_post_delete(actor, forum_slug, topic_slug, post_id)
  end

  describe "communication visibility" do
    test "a pending post is visible only to its author, matching IP, and staff", %{
      forum: forum,
      topic: topic
    } do
      {post, author} = unapproved_post(topic)
      other = confirmed_user_fixture()

      assert {:ok, loaded} =
               Posts.show_topic_post(actor(author), forum.short_name, topic.slug, post.id)

      assert loaded.id == post.id

      assert Posts.show_topic_post(actor(other), forum.short_name, topic.slug, post.id) ==
               {:error, :not_found}

      assert {:ok, _loaded} =
               Posts.show_topic_post(
                 actor(other, ip: post.ip),
                 forum.short_name,
                 topic.slug,
                 post.id
               )

      assert {:ok, _loaded} =
               Posts.show_topic_post(
                 actor(moderator_user_fixture()),
                 forum.short_name,
                 topic.slug,
                 post.id
               )
    end

    test "a destroyed post is unavailable to ordinary viewers but remains visible to staff", %{
      forum: forum,
      topic: topic
    } do
      post =
        post_fixture(topic, confirmed_user_fixture())
        |> Ecto.Changeset.change(destroyed_content: true)
        |> Repo.update!()

      assert Posts.show_topic_post(actor(), forum.short_name, topic.slug, post.id) ==
               {:error, :not_found}

      assert {:ok, loaded} =
               Posts.show_topic_post(
                 actor(moderator_user_fixture()),
                 forum.short_name,
                 topic.slug,
                 post.id
               )

      assert loaded.id == post.id
    end
  end

  describe "parent scoping" do
    test "moderation actions cannot address a post through another topic", %{
      forum: forum,
      topic: topic
    } do
      moderator = moderator_user_fixture()
      wrong_topic = topic_fixture(forum)
      {unapproved, _author} = unapproved_post(topic)
      visible = visible_post(topic)
      hidden = already_hidden_post(topic)

      assert Posts.create_post_approve(
               actor(moderator),
               forum.short_name,
               wrong_topic.slug,
               unapproved.id
             ) == {:error, :not_found}

      assert Posts.create_post_hide(
               actor(moderator),
               forum.short_name,
               wrong_topic.slug,
               visible.id,
               %{"deletion_reason" => "Spam"}
             ) == {:error, :not_found}

      assert Posts.delete_post_hide(
               actor(moderator),
               forum.short_name,
               wrong_topic.slug,
               hidden.id
             ) == {:error, :not_found}

      assert Posts.create_post_delete(
               actor(moderator),
               forum.short_name,
               wrong_topic.slug,
               visible.id
             ) == {:error, :not_found}

      refute Repo.reload!(unapproved).approved
      refute Repo.reload!(visible).hidden_from_users
      refute Repo.reload!(visible).destroyed_content
      assert Repo.reload!(hidden).hidden_from_users
      no_moderation_logs!()
    end
  end

  describe "create_post_approve/2" do
    test "denies an anonymous actor", %{topic: topic} do
      {post, _author} = unapproved_post(topic)

      assert approve_post(actor(), "#{post.id}") == {:error, :unauthorized}
      refute Repo.reload!(post).approved
      no_moderation_logs!()
    end

    test "denies a regular user", %{topic: topic} do
      {post, _author} = unapproved_post(topic)

      assert approve_post(actor(confirmed_user_fixture()), "#{post.id}") ==
               {:error, :unauthorized}

      refute Repo.reload!(post).approved
      no_moderation_logs!()
    end

    test "a moderator approves the post, which is returned with topic and forum preloaded",
         %{forum: forum, topic: topic} do
      {post, _author} = unapproved_post(topic)
      moderator = moderator_user_fixture()

      assert {:ok, %Post{} = approved} = approve_post(actor(moderator), "#{post.id}")

      assert approved.id == post.id
      assert approved.approved
      assert %{topic: %{forum: %Forum{}}} = approved
      assert approved.topic.id == topic.id
      assert approved.topic.forum.id == forum.id

      assert Repo.reload!(post).approved
    end

    test "the moderation log names the post and topic byte-for-byte",
         %{forum: forum, topic: topic} do
      {post, _author} = unapproved_post(topic)
      moderator = moderator_user_fixture()

      assert {:ok, _} = approve_post(actor(moderator), "#{post.id}")

      log = Repo.one!(ModerationLog)
      assert log.user_id == moderator.id
      assert log.type == "Topic.Post.Approve:create"
      assert log.body == "Approved forum post ##{post.id} in topic '#{topic.title}'"

      assert log.subject_path ==
               "/forums/#{forum.short_name}/topics/#{topic.slug}?post_id=#{post.id}#post_#{post.id}"
    end

    test "approving increments the author's forum posts_count by one", %{topic: topic} do
      {post, author} = unapproved_post(topic)
      before = Repo.get!(User, author.id).posts_count

      assert {:ok, _} = approve_post(actor(moderator_user_fixture()), "#{post.id}")

      assert Repo.get!(User, author.id).posts_count == before + 1
    end

    test "a well-formed id naming no row is not found" do
      assert approve_post(actor(moderator_user_fixture()), "999999999") ==
               {:error, :not_found}

      no_moderation_logs!()
    end

    test "an id that cannot name a row is not found" do
      assert approve_post(actor(moderator_user_fixture()), "abc") == {:error, :not_found}
      no_moderation_logs!()
    end
  end

  # A visible reply authored by a fresh user, ready to be hidden.
  defp visible_post(topic) do
    post_fixture(topic, confirmed_user_fixture(), %{"body" => "Rule-breaking post"})
  end

  # An already-hidden reply, set up through the auth-free/log-free engine so no
  # moderation log exists before the restore under test runs.
  defp already_hidden_post(topic) do
    moderator = moderator_user_fixture()

    {:ok, hidden} =
      hide_post(actor(moderator), visible_post(topic).id, %{"deletion_reason" => "Spam"})

    Repo.delete_all(ModerationLog)

    hidden
  end

  describe "create_post_hide/3" do
    test "denies an anonymous actor", %{topic: topic} do
      post = visible_post(topic)

      assert hide_post(actor(), "#{post.id}", %{"deletion_reason" => "Spam"}) ==
               {:error, :unauthorized}

      refute Repo.reload!(post).hidden_from_users
      no_moderation_logs!()
    end

    test "denies a regular user, leaving the post unchanged", %{topic: topic} do
      post = visible_post(topic)

      assert hide_post(actor(confirmed_user_fixture()), "#{post.id}", %{
               "deletion_reason" => "Spam"
             }) ==
               {:error, :unauthorized}

      reloaded = Repo.reload!(post)
      refute reloaded.hidden_from_users
      assert reloaded.deletion_reason == ""
      no_moderation_logs!()
    end

    test "a moderator hides the post, which is returned with topic and forum preloaded",
         %{forum: forum, topic: topic} do
      post = visible_post(topic)
      moderator = moderator_user_fixture()

      assert {:ok, %Post{} = hidden} =
               hide_post(actor(moderator), "#{post.id}", %{"deletion_reason" => "Spam"})

      assert hidden.id == post.id
      assert hidden.hidden_from_users
      assert hidden.deletion_reason == "Spam"
      assert %{topic: %{forum: %Forum{}}} = hidden
      assert hidden.topic.id == topic.id
      assert hidden.topic.forum.id == forum.id

      reloaded = Repo.reload!(post)
      assert reloaded.hidden_from_users
      assert reloaded.deletion_reason == "Spam"
    end

    test "the moderation log names the post, topic, and reason byte-for-byte",
         %{forum: forum, topic: topic} do
      post = visible_post(topic)
      moderator = moderator_user_fixture()

      assert {:ok, _} =
               hide_post(actor(moderator), "#{post.id}", %{"deletion_reason" => "Spam"})

      log = Repo.one!(ModerationLog)
      assert log.user_id == moderator.id
      assert log.type == "Topic.Post.Hide:create"
      assert log.body == "Deleted forum post ##{post.id} in topic '#{topic.title}' (Spam)"

      assert log.subject_path ==
               "/forums/#{forum.short_name}/topics/#{topic.slug}?post_id=#{post.id}#post_#{post.id}"
    end

    test "hiding a topic's only post keeps the topic's place and the forum's last post",
         %{forum: forum, topic: topic} do
      moderator = moderator_user_fixture()
      created_at = DateTime.add(DateTime.utc_now(:second), -1, :hour)

      Repo.update_all(where(Topic, id: ^topic.id),
        set: [created_at: created_at, last_replied_to_at: created_at]
      )

      %{posts: [only_post]} = rejected_topic = topic_fixture(forum)
      last_replied_to_at = Repo.reload!(rejected_topic).last_replied_to_at

      assert {:ok, _} =
               hide_post(actor(moderator), "#{only_post.id}", %{"deletion_reason" => "Spam"})

      rejected_topic = Repo.reload!(rejected_topic)
      assert rejected_topic.last_post_id == nil
      assert rejected_topic.last_replied_to_at == last_replied_to_at
      assert Repo.reload!(forum).last_post_id == Repo.reload!(topic).last_post_id

      assert {:ok, %{topics: topics}} =
               Forums.show_forum_page(actor(moderator), forum.short_name, %{
                 page_number: 1,
                 page_size: 25
               })

      assert Enum.map(topics, & &1.id) == [rejected_topic.id, topic.id]
    end

    test "a blank deletion reason is a rejected changeset carrying the loaded post",
         %{topic: topic} do
      post = visible_post(topic)

      assert {:error, %Ecto.Changeset{data: %Post{} = returned}} =
               hide_post(actor(moderator_user_fixture()), "#{post.id}", %{
                 "deletion_reason" => ""
               })

      assert returned.id == post.id
      refute Repo.reload!(post).hidden_from_users
      no_moderation_logs!()
    end

    test "a well-formed id naming no row is not found" do
      assert hide_post(actor(moderator_user_fixture()), "999999999", %{
               "deletion_reason" => "Spam"
             }) ==
               {:error, :not_found}

      no_moderation_logs!()
    end

    test "an id that cannot name a row is not found" do
      assert hide_post(actor(moderator_user_fixture()), "abc", %{
               "deletion_reason" => "Spam"
             }) ==
               {:error, :not_found}

      no_moderation_logs!()
    end
  end

  describe "delete_post_hide/2" do
    test "denies an anonymous actor", %{topic: topic} do
      post = already_hidden_post(topic)

      assert unhide_post(actor(), "#{post.id}") == {:error, :unauthorized}
      assert Repo.reload!(post).hidden_from_users
      no_moderation_logs!()
    end

    test "denies a regular user, leaving the post hidden", %{topic: topic} do
      post = already_hidden_post(topic)

      assert unhide_post(actor(confirmed_user_fixture()), "#{post.id}") ==
               {:error, :unauthorized}

      reloaded = Repo.reload!(post)
      assert reloaded.hidden_from_users
      assert reloaded.deletion_reason == "Spam"
      no_moderation_logs!()
    end

    test "a moderator restores the post, which is returned with topic and forum preloaded",
         %{forum: forum, topic: topic} do
      post = already_hidden_post(topic)
      moderator = moderator_user_fixture()

      assert {:ok, %Post{} = restored} = unhide_post(actor(moderator), "#{post.id}")

      assert restored.id == post.id
      refute restored.hidden_from_users
      assert restored.deletion_reason == ""
      assert %{topic: %{forum: %Forum{}}} = restored
      assert restored.topic.id == topic.id
      assert restored.topic.forum.id == forum.id

      reloaded = Repo.reload!(post)
      refute reloaded.hidden_from_users
      assert reloaded.deletion_reason == ""
    end

    test "the moderation log names the post and topic byte-for-byte",
         %{forum: forum, topic: topic} do
      post = already_hidden_post(topic)
      moderator = moderator_user_fixture()

      assert {:ok, _} = unhide_post(actor(moderator), "#{post.id}")

      log = Repo.one!(ModerationLog)
      assert log.user_id == moderator.id
      assert log.type == "Topic.Post.Hide:delete"
      assert log.body == "Restored forum post ##{post.id} in topic '#{topic.title}'"

      assert log.subject_path ==
               "/forums/#{forum.short_name}/topics/#{topic.slug}?post_id=#{post.id}#post_#{post.id}"
    end

    test "a well-formed id naming no row is not found" do
      assert unhide_post(actor(moderator_user_fixture()), "999999999") ==
               {:error, :not_found}

      no_moderation_logs!()
    end

    test "an id that cannot name a row is not found" do
      assert unhide_post(actor(moderator_user_fixture()), "abc") == {:error, :not_found}
      no_moderation_logs!()
    end
  end

  describe "create_post_delete/2" do
    test "denies an anonymous actor, leaving the body intact", %{topic: topic} do
      post = already_hidden_post(topic)

      assert destroy_post(actor(), "#{post.id}") == {:error, :unauthorized}

      reloaded = Repo.reload!(post)
      assert reloaded.body == "Rule-breaking post"
      refute reloaded.destroyed_content
      no_moderation_logs!()
    end

    test "denies a regular user, leaving the body intact", %{topic: topic} do
      post = already_hidden_post(topic)

      assert destroy_post(actor(confirmed_user_fixture()), "#{post.id}") ==
               {:error, :unauthorized}

      reloaded = Repo.reload!(post)
      assert reloaded.body == "Rule-breaking post"
      refute reloaded.destroyed_content
      no_moderation_logs!()
    end

    test "a moderator destroys the post, which is returned with topic and forum preloaded",
         %{forum: forum, topic: topic} do
      post = already_hidden_post(topic)
      moderator = moderator_user_fixture()

      assert {:ok, %Post{} = destroyed} = destroy_post(actor(moderator), "#{post.id}")

      assert destroyed.id == post.id
      assert %{topic: %{forum: %Forum{}}} = destroyed
      assert destroyed.topic.id == topic.id
      assert destroyed.topic.forum.id == forum.id

      # The destroy engine blanks the body and marks the content destroyed. It
      # requires the post to already be hidden and preserves its hidden state.
      reloaded = Repo.reload!(post)
      assert reloaded.body == ""
      assert reloaded.destroyed_content
      assert reloaded.hidden_from_users
      assert reloaded.deletion_reason == "Spam"
    end

    # The engine authorizes :hide and never inspects hidden_from_users, so an
    # already-hidden post is destroyable too; it keeps its hidden flag and reason
    # while the text is wiped.
    test "destroys an already-hidden post, keeping its hidden flag and reason", %{topic: topic} do
      post = already_hidden_post(topic)

      # Set up through the log-free engine, so no log exists before the destroy.
      no_moderation_logs!()

      assert {:ok, %Post{}} = destroy_post(actor(moderator_user_fixture()), "#{post.id}")

      reloaded = Repo.reload!(post)
      assert reloaded.body == ""
      assert reloaded.destroyed_content
      assert reloaded.hidden_from_users
      assert reloaded.deletion_reason == "Spam"
    end

    test "destroying an approved post decrements the author's posts_count",
         %{topic: topic} do
      author = confirmed_user_fixture()
      post = post_fixture(topic, author, %{"body" => "An approved post"})
      before = Repo.get!(User, author.id).posts_count

      assert post.approved

      assert {:ok, _} =
               Posts.create_post_hide(
                 actor(moderator_user_fixture()),
                 topic.forum.short_name,
                 topic.slug,
                 post.id,
                 %{"deletion_reason" => "Spam"}
               )

      assert {:ok, _} = destroy_post(actor(moderator_user_fixture()), "#{post.id}")
      assert Repo.get!(User, author.id).posts_count == before - 1
    end

    test "destroying a withheld post does not decrement the author's posts_count",
         %{topic: topic} do
      {post, author} = unapproved_post(topic)
      before = Repo.get!(User, author.id).posts_count

      refute post.approved

      assert {:ok, _} =
               Posts.create_post_hide(
                 actor(moderator_user_fixture()),
                 topic.forum.short_name,
                 topic.slug,
                 post.id,
                 %{"deletion_reason" => "Spam"}
               )

      assert {:ok, _} = destroy_post(actor(moderator_user_fixture()), "#{post.id}")
      assert Repo.get!(User, author.id).posts_count == before
    end

    test "the moderation log names the post and topic byte-for-byte",
         %{forum: forum, topic: topic} do
      post = already_hidden_post(topic)
      moderator = moderator_user_fixture()

      assert {:ok, _} = destroy_post(actor(moderator), "#{post.id}")

      log = Repo.one!(ModerationLog)
      assert log.user_id == moderator.id
      assert log.type == "Topic.Post.Delete:create"
      assert log.body == "Destroyed forum post ##{post.id} in topic '#{topic.title}'"

      assert log.subject_path ==
               "/forums/#{forum.short_name}/topics/#{topic.slug}?post_id=#{post.id}#post_#{post.id}"
    end

    test "a well-formed id naming no row is not found" do
      assert destroy_post(actor(moderator_user_fixture()), "999999999") ==
               {:error, :not_found}

      no_moderation_logs!()
    end

    test "an id that cannot name a row is not found" do
      assert destroy_post(actor(moderator_user_fixture()), "abc") == {:error, :not_found}
      no_moderation_logs!()
    end
  end

  describe "list_post_history/4" do
    # Unlike the moderation actions above, list_post_history is a public read routed
    # by forum short name and topic slug (not a bare post id), so it takes the
    # loaded topic's addressing rather than a raw "#{post.id}" string.

    test "an anonymous actor reads the history of a visible post",
         %{forum: forum, topic: topic} do
      [post] = topic.posts

      assert {:ok, {loaded_topic, %Post{} = loaded_post, versions}} =
               Posts.list_post_history(actor(), forum.short_name, topic.slug, "#{post.id}")

      assert loaded_topic.id == topic.id
      assert loaded_post.id == post.id

      # The post comes back with the associations the history page renders.
      assert %{topic: %{forum: %Forum{}}} = loaded_post
      assert loaded_post.topic.id == topic.id
      assert loaded_post.topic.forum.id == forum.id

      # A never-edited post has recorded no versions.
      assert versions == []
    end

    test "an unknown forum is not found", %{topic: topic} do
      [post] = topic.posts

      assert Posts.list_post_history(actor(), "nonexistent", topic.slug, "#{post.id}") ==
               {:error, :not_found}
    end

    test "an unknown topic in a real forum is not found", %{forum: forum} do
      assert Posts.list_post_history(actor(), forum.short_name, "nonexistent", "1") ==
               {:error, :not_found}
    end

    test "an unknown post id in a real topic is not found", %{forum: forum, topic: topic} do
      assert Posts.list_post_history(actor(), forum.short_name, topic.slug, "999999999") ==
               {:error, :not_found}
    end

    test "an anonymous actor cannot read the history of a hidden post",
         %{forum: forum, topic: topic} do
      post = already_hidden_post(topic)

      assert Posts.list_post_history(actor(), forum.short_name, topic.slug, "#{post.id}") ==
               {:error, :unauthorized}
    end

    test "a regular user cannot read the history of a hidden post",
         %{forum: forum, topic: topic} do
      post = already_hidden_post(topic)

      assert Posts.list_post_history(
               actor(confirmed_user_fixture()),
               forum.short_name,
               topic.slug,
               "#{post.id}"
             ) ==
               {:error, :unauthorized}
    end

    test "a moderator reads the history of a hidden post", %{forum: forum, topic: topic} do
      post = already_hidden_post(topic)

      assert {:ok, {_topic, %Post{} = loaded_post, versions}} =
               Posts.list_post_history(
                 actor(moderator_user_fixture()),
                 forum.short_name,
                 topic.slug,
                 "#{post.id}"
               )

      assert loaded_post.id == post.id
      assert loaded_post.hidden_from_users
      assert is_list(versions)
    end

    test "an edited post reports the recorded version, its author, and the pre-edit body",
         %{forum: forum, topic: topic} do
      author = confirmed_user_fixture()
      post = post_fixture(topic, author, %{"body" => "Original post body"})

      {:ok, _} =
        Posts.update_post(actor(author), forum.short_name, topic.slug, post.id, %{
          "body" => "Original post body plus an edit",
          "edit_reason" => "typo fix"
        })

      assert {:ok, {_topic, _post, [%PostVersion{} = version]}} =
               Posts.list_post_history(actor(), forum.short_name, topic.slug, "#{post.id}")

      # previous_body records the body as it stood before the edit, so the
      # single version carries the original text and names its editor.
      assert version.previous_body == "Original post body"
      assert version.user.id == author.id
    end

    test "the history is capped at the most recent 25 versions",
         %{forum: forum, topic: topic} do
      author = confirmed_user_fixture()
      post = post_fixture(topic, author, %{"body" => "edit 0"})

      # Each update records one version, so 26 edits record 26 versions; the
      # query limits the result to 25. Database ids break same-second timestamp
      # ties, so the most recently serialized edit is first.
      Enum.reduce(1..26, post, fn n, current ->
        {:ok, updated} =
          Posts.update_post(actor(author), forum.short_name, topic.slug, current.id, %{
            "body" => "edit #{n}"
          })

        updated
      end)

      assert {:ok, {_topic, _post, versions}} =
               Posts.list_post_history(actor(), forum.short_name, topic.slug, "#{post.id}")

      assert length(versions) == 25
    end
  end

  describe "load_report_target/4" do
    test "loads a visible post through its forum and topic parents" do
      forum = forum_fixture()
      topic = topic_fixture(forum)
      post = hd(topic.posts)

      assert {:ok, loaded} =
               Posts.load_report_target(actor(), forum.short_name, topic.slug, post.id)

      assert loaded.id == post.id
      assert loaded.topic.id == topic.id
      assert loaded.topic.forum.id == forum.id
    end

    test "normalizes malformed, missing, and mismatched route locators" do
      first_forum = forum_fixture()
      second_forum = forum_fixture()
      topic = topic_fixture(first_forum)
      post = hd(topic.posts)

      assert Posts.load_report_target(
               actor(),
               first_forum.short_name,
               topic.slug,
               "not-an-id"
             ) == {:error, :not_found}

      assert Posts.load_report_target(
               actor(),
               second_forum.short_name,
               topic.slug,
               post.id
             ) == {:error, :not_found}

      assert Posts.load_report_target(
               actor(),
               first_forum.short_name,
               "missing-topic",
               post.id
             ) == {:error, :not_found}
    end

    test "rejects a hidden post for a regular user" do
      forum = forum_fixture()
      topic = topic_fixture(forum)
      post = hd(topic.posts)

      hidden =
        post
        |> Ecto.Changeset.change(hidden_from_users: true)
        |> Repo.update!()

      assert Posts.load_report_target(
               actor(confirmed_user_fixture()),
               forum.short_name,
               topic.slug,
               hidden.id
             ) == {:error, :unauthorized}
    end
  end

  describe "create_post/4" do
    # This is a write, so it runs verify_write_access first (ban -> :ban,
    # missing fingerprint -> :unauthorized), both before any loading, then the
    # forum/topic load-and-authorize chain and finally the insert engine.

    test "a banned actor is rejected before any loading, even with an unknown forum" do
      # verify_write_access runs first, so a banned actor is {:error, :ban} even
      # against a forum slug that does not exist (a missing forum would otherwise
      # surface as :unauthorized). Getting :ban pins that the ban check precedes
      # the load.
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Posts.create_post(actor, "nonexistent", "whatever", %{"body" => "Hi"}) ==
               {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized before any loading" do
      # The fingerprint requirement precedes loading, so a missing forum still
      # answers unauthorized from the write-access gate rather than the loader.
      anonymous = actor(nil, fingerprint: nil)

      assert Posts.create_post(anonymous, "nonexistent", "whatever", %{"body" => "Hi"}) ==
               {:error, :unauthorized}
    end

    test "a valid anonymous fingerprinted actor creates a post with no author",
         %{forum: forum, topic: topic} do
      # actor(nil) carries the shared fingerprint, so it clears verify_write_access
      # and reaches the public forum/topic create; the engine records the post
      # with a nil user (anonymous attribution).
      assert {:ok, %Post{} = post} =
               Posts.create_post(actor(nil, ip: random_ip()), forum.short_name, topic.slug, %{
                 "body" => "An anonymous reply"
               })

      assert post.user_id == nil
      assert post.body == "An anonymous reply"
      assert post.topic.id == topic.id
      assert post.topic.forum.id == forum.id

      # The topic carries its author preloaded for the firehose broadcast.
      assert %{user: _} = post.topic
    end

    test "a signed-in actor creates a post attributed to the user",
         %{forum: forum, topic: topic} do
      user = confirmed_user_fixture()

      assert {:ok, %Post{} = post} =
               Posts.create_post(actor(user), forum.short_name, topic.slug, %{
                 "body" => "A logged-in reply"
               })

      assert post.user_id == user.id
      assert post.body == "A logged-in reply"
    end

    test "a regular actor cannot post in a locked topic", %{forum: forum, topic: topic} do
      # authorize(:create_post, topic) permits no rule on a locked topic, so a
      # regular actor is unauthorized after the load.
      moderator = moderator_user_fixture()

      {:ok, {_forum, _topic}} =
        Philomena.Topics.create_topic_lock(
          actor(moderator),
          forum.short_name,
          topic.slug,
          %{"lock_reason" => "Test lock"}
        )

      assert Posts.create_post(actor(confirmed_user_fixture()), forum.short_name, topic.slug, %{
               "body" => "Reply to a locked topic"
             }) ==
               {:error, :unauthorized}
    end

    test "an unknown topic in a real forum is not found", %{forum: forum} do
      assert Posts.create_post(
               actor(confirmed_user_fixture()),
               forum.short_name,
               "nonexistent-topic",
               %{"body" => "Reply to nothing"}
             ) ==
               {:error, :not_found}
    end

    test "a blank body is a rejected insert carrying the forum and topic",
         %{forum: forum, topic: topic} do
      assert {:error, %Ecto.Changeset{data: %Post{} = returned}} =
               Posts.create_post(actor(confirmed_user_fixture()), forum.short_name, topic.slug, %{
                 "body" => ""
               })

      assert returned.topic.id == topic.id
      assert returned.topic.forum.id == forum.id

      # No reply was inserted beyond the topic's own first post.
      assert Repo.aggregate(from(p in Post, where: p.topic_id == ^topic.id), :count) == 1
    end

    test "an approved post increments the author's forum posts_count by one",
         %{forum: forum, topic: topic} do
      # A fresh confirmed user's plain (link-free) reply is auto-approved, so the
      # post-insert bookkeeping bumps the author's forum post total.
      author = confirmed_user_fixture()
      before = Repo.get!(User, author.id).posts_count

      assert {:ok, post} =
               Posts.create_post(actor(author), forum.short_name, topic.slug, %{
                 "body" => "A trustworthy reply"
               })

      assert post.approved
      assert Repo.get!(User, author.id).posts_count == before + 1
    end

    test "a withheld post does not increment the author's forum posts_count and is reported",
         %{forum: forum, topic: topic} do
      author = confirmed_user_fixture()
      before = Repo.get!(User, author.id).posts_count
      approval_rule!()

      assert {:ok, post} =
               Posts.create_post(actor(author), forum.short_name, topic.slug, %{
                 "body" => "A reply containing https://spam.example/"
               })

      refute post.approved
      assert Repo.get!(User, author.id).posts_count == before
      assert Repo.aggregate(from(r in Report, where: r.post_id == ^post.id), :count) == 1
    end

    test "an over-limit actor is rate limited and no post is created",
         %{forum: forum, topic: topic} do
      # The :post_create counter is primed past the limit, so the rate check
      # (after write-access, before the topic load and insert) refuses the write.
      actor = actor(confirmed_user_fixture())
      exceed_rate_limit(actor, :post_create)

      assert Posts.create_post(actor, forum.short_name, topic.slug, %{"body" => "A reply"}) ==
               {:error, :rate_limited}

      # Only the topic's own first post remains.
      assert Repo.aggregate(from(p in Post, where: p.topic_id == ^topic.id), :count) == 1
    end

    test "a successful create records the counter", %{forum: forum, topic: topic} do
      actor = actor(confirmed_user_fixture())
      track_rate_limit(actor, :post_create)

      assert {:ok, %Post{}} =
               Posts.create_post(actor, forum.short_name, topic.slug, %{"body" => "A reply"})

      assert rate_limit_count(actor, :post_create) == "1"
    end

    test "the rate check precedes the topic load: over-limit against an unknown forum is still rate limited" do
      # show_forum_topic runs after the rate check, so an over-limit actor gets
      # :rate_limited rather than the :unauthorized a missing forum yields.
      actor = actor(confirmed_user_fixture())
      exceed_rate_limit(actor, :post_create)

      assert Posts.create_post(actor, "nonexistent", "whatever", %{"body" => "Hi"}) ==
               {:error, :rate_limited}
    end
  end

  describe "edit_post/4" do
    # This backs the edit form, so it refuses bans and then runs the same
    # load-and-authorize chain update_post/5 uses.

    test "a banned actor is rejected before any loading, even with an unknown forum" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Posts.edit_post(actor, "nonexistent", "whatever", "1") ==
               {:error, :ban}
    end

    test "the post's author loads the form, even without a fingerprint",
         %{forum: forum, topic: topic} do
      author = confirmed_user_fixture()
      post = post_fixture(topic, author)

      assert {:ok, %Ecto.Changeset{data: %Post{} = loaded} = changeset} =
               Posts.edit_post(
                 actor(author, fingerprint: nil),
                 forum.short_name,
                 topic.slug,
                 "#{post.id}"
               )

      assert loaded.id == post.id

      # The changeset is over the loaded post, driving the edit form.
      assert %Post{} = changeset.data
      assert changeset.data.id == post.id
    end

    test "another regular user cannot load the form", %{forum: forum, topic: topic} do
      post = post_fixture(topic, confirmed_user_fixture())

      assert Posts.edit_post(
               actor(confirmed_user_fixture()),
               forum.short_name,
               topic.slug,
               "#{post.id}"
             ) ==
               {:error, :unauthorized}
    end

    test "a moderator loads the form", %{forum: forum, topic: topic} do
      post = post_fixture(topic, confirmed_user_fixture())

      assert {:ok, %Ecto.Changeset{data: %Post{} = loaded}} =
               Posts.edit_post(
                 actor(moderator_user_fixture()),
                 forum.short_name,
                 topic.slug,
                 "#{post.id}"
               )

      assert loaded.id == post.id
    end

    test "an unknown post id in a real topic is not found", %{forum: forum, topic: topic} do
      assert Posts.edit_post(
               actor(confirmed_user_fixture()),
               forum.short_name,
               topic.slug,
               "999999999"
             ) ==
               {:error, :not_found}
    end
  end

  describe "update_post/5" do
    # This is a write, so it runs verify_write_access first (ban -> :ban), then
    # the same load-and-authorize chain edit_post/4 uses, then the edit
    # engine which records a version.

    test "a banned actor is rejected before any loading, even with an unknown forum" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Posts.update_post(actor, "nonexistent", "whatever", "1", %{"body" => "Edited"}) ==
               {:error, :ban}
    end

    test "the author edits the body and a version is recorded",
         %{forum: forum, topic: topic} do
      author = confirmed_user_fixture()
      post = post_fixture(topic, author, %{"body" => "Original reply body"})

      assert {:ok, %Post{} = updated} =
               Posts.update_post(actor(author), forum.short_name, topic.slug, "#{post.id}", %{
                 "body" => "Original reply body plus an edit",
                 "edit_reason" => "typo"
               })

      assert updated.body == "Original reply body plus an edit"
      assert Repo.reload!(post).body == "Original reply body plus an edit"
      assert Repo.exists?(from v in PostVersion, where: v.post_id == ^post.id)

      assert {:ok, {_topic, _post, [%PostVersion{} = version]}} =
               Posts.list_post_history(actor(), forum.short_name, topic.slug, "#{post.id}")

      assert version.previous_body == "Original reply body"
    end

    test "editing an approved post into a withheld one decrements its count once and reports it",
         %{forum: forum, topic: topic} do
      approval_rule!()
      author = confirmed_user_fixture()
      post = post_fixture(topic, author, %{"body" => "An ordinary reply"})
      before = Repo.get!(User, author.id).posts_count

      assert {:ok, %Post{approved: false}} =
               Posts.update_post(actor(author), forum.short_name, topic.slug, post.id, %{
                 "body" => "Now containing https://spam.example/"
               })

      assert Repo.get!(User, author.id).posts_count == before - 1
      assert Repo.aggregate(from(r in Report, where: r.post_id == ^post.id), :count) == 1

      assert {:ok, %Post{approved: false}} =
               Posts.update_post(actor(author), forum.short_name, topic.slug, post.id, %{
                 "body" => "Still containing https://spam.example/"
               })

      assert Repo.get!(User, author.id).posts_count == before - 1
      assert Repo.aggregate(from(r in Report, where: r.post_id == ^post.id), :count) == 1

      assert {:ok, %Post{approved: true}} =
               Posts.create_post_approve(
                 actor(moderator_user_fixture()),
                 forum.short_name,
                 topic.slug,
                 post.id
               )

      assert Repo.get!(User, author.id).posts_count == before
    end

    test "editing the external link out of a withheld post approves it and restores its count",
         %{forum: forum, topic: topic} do
      {post, author} = unapproved_post(topic)
      before = Repo.get!(User, author.id).posts_count

      assert {:ok, %Post{approved: true}} =
               Posts.update_post(actor(author), forum.short_name, topic.slug, post.id, %{
                 "body" => "check this out"
               })

      assert Repo.get!(User, author.id).posts_count == before + 1
    end

    test "another regular user cannot edit, leaving the body unchanged",
         %{forum: forum, topic: topic} do
      post = post_fixture(topic, confirmed_user_fixture(), %{"body" => "Original reply body"})

      assert Posts.update_post(
               actor(confirmed_user_fixture()),
               forum.short_name,
               topic.slug,
               "#{post.id}",
               %{"body" => "Hijacked"}
             ) ==
               {:error, :unauthorized}

      assert Repo.reload!(post).body == "Original reply body"
    end

    test "a blank body is a rejected changeset carrying the loaded post",
         %{forum: forum, topic: topic} do
      author = confirmed_user_fixture()
      post = post_fixture(topic, author, %{"body" => "Original reply body"})

      assert {:error, %Ecto.Changeset{data: %Post{} = returned}} =
               Posts.update_post(actor(author), forum.short_name, topic.slug, "#{post.id}", %{
                 "body" => ""
               })

      assert returned.id == post.id
      assert Repo.reload!(post).body == "Original reply body"
    end

    test "an unknown post id in a real topic is not found", %{forum: forum, topic: topic} do
      assert Posts.update_post(
               actor(confirmed_user_fixture()),
               forum.short_name,
               topic.slug,
               "999999999",
               %{"body" => "Edited"}
             ) ==
               {:error, :not_found}
    end
  end
end
