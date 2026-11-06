defmodule Philomena.CommentsTest do
  @moduledoc """
  Context-level tests for `Philomena.Comments`.

  `search_comments/4` runs a comment search against OpenSearch and applies the
  viewer's visibility rules. `approve_comment/3` is the actor-first moderation
  wrapper: it pins the authorization matrix, the two global error shapes routed
  through the id guard, the approval effects (report closure, author comment
  count, reindex), and the moderation log entry - type, body, and subject path
  asserted exactly.
  """

  use Philomena.DataCase, async: false

  @moduletag :search

  import Ecto.Query
  import Philomena.AttributionFixtures
  import Philomena.CommentsFixtures
  import Philomena.FiltersFixtures
  import Philomena.ImagesFixtures
  import Philomena.ReportsFixtures
  import Philomena.RulesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Comments
  alias Philomena.Filters.Filter
  alias Philomena.Repo
  alias Philomena.Comments.{Comment, CommentHistory, CommentVersion}
  alias Philomena.Images.Image
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Reports.Report
  alias Philomena.Users.User
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  # A truthy ban value in the shape production passes (the result of
  # Philomena.Bans.find/3); only its presence matters to the write-access and
  # not-banned checks the actor-first writes run first.
  @ban %{
    reason: "Rule #0",
    valid_until: ~U[3000-01-01 00:00:00Z],
    generated_ban_id: "U123456",
    type: "User"
  }

  setup do
    Search.clear_index!(Comment)
    :ok
  end

  @pagination %{page_number: 1, page_size: 25}
  @empty_filter %Filter{hidden_tag_ids: []}

  describe "query_comments/4" do
    test "returns an error for an uncompilable query string" do
      assert {:error, msg} =
               Comments.query_comments(
                 actor(),
                 @empty_filter,
                 "created_at.gte:not-a-date",
                 @pagination
               )

      assert is_binary(msg)
    end

    test "finds an indexed comment with preloads for an anonymous viewer" do
      user = user_fixture()
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "Test grapefruit comment"})
      SearchHelpers.reindex_all!(Comment)

      assert {:ok, results} =
               Comments.query_comments(actor(), @empty_filter, "grapefruit", @pagination)

      assert [entry] = results.entries
      assert entry.id == comment.id

      # Display preloads are loaded on the returned records.
      assert %Philomena.Users.User{} = entry.user
      assert is_list(entry.image.tags)
      assert is_list(entry.image.sources)
    end

    test "excludes a hidden comment from an anonymous viewer" do
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "Test grapefruit comment"})

      comment
      |> Ecto.Changeset.change(hidden_from_users: true)
      |> Repo.update!()

      SearchHelpers.reindex_all!(Comment)

      assert {:ok, results} =
               Comments.query_comments(actor(), @empty_filter, "grapefruit", @pagination)

      assert results.entries == []
    end

    test "includes a hidden comment for a moderator" do
      moderator = moderator_user_fixture()
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "Test grapefruit comment"})

      comment
      |> Ecto.Changeset.change(hidden_from_users: true)
      |> Repo.update!()

      SearchHelpers.reindex_all!(Comment)

      assert {:ok, results} =
               Comments.query_comments(
                 actor(moderator),
                 @empty_filter,
                 "grapefruit",
                 @pagination
               )

      assert [entry] = results.entries
      assert entry.id == comment.id
    end

    test "uses abilities independently for hidden-comment visibility and sensitive fields" do
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "Test grapefruit comment"})

      comment
      |> Ecto.Changeset.change(hidden_from_users: true)
      |> Repo.update!()

      assistant = assistant_user_fixture()
      comment_assistant = %{assistant | role_map: %{"Comment" => %{"moderator" => []}}}
      SearchHelpers.reindex_all!(Comment)

      assert {:ok, plain_results} =
               Comments.query_comments(
                 actor(assistant),
                 @empty_filter,
                 "grapefruit",
                 @pagination
               )

      assert plain_results.entries == []

      assert {:ok, scoped_results} =
               Comments.query_comments(
                 actor(comment_assistant),
                 @empty_filter,
                 "grapefruit",
                 @pagination
               )

      assert Enum.map(scoped_results.entries, & &1.id) == [comment.id]

      ip_query = "ip:#{comment.ip}"

      assert {:ok, assistant_ip_results} =
               Comments.query_comments(
                 actor(comment_assistant),
                 @empty_filter,
                 ip_query,
                 @pagination
               )

      assert assistant_ip_results.entries == []

      assert {:ok, moderator_ip_results} =
               Comments.query_comments(
                 actor(moderator_user_fixture()),
                 @empty_filter,
                 ip_query,
                 @pagination
               )

      assert Enum.map(moderator_ip_results.entries, & &1.id) == [comment.id]
    end

    test "shows a pending comment to its author but not to another user" do
      author = confirmed_user_fixture()
      image = image_fixture()
      comment = pending_comment(image, author)
      Repo.update!(Ecto.Changeset.change(comment, body: "Test grapefruit comment"))
      SearchHelpers.reindex_all!(Comment)

      assert {:ok, %{entries: [%Comment{id: id}]}} =
               Comments.query_comments(actor(author), @empty_filter, "grapefruit", @pagination)

      assert id == comment.id

      assert {:ok, %{entries: []}} =
               Comments.query_comments(
                 actor(confirmed_user_fixture()),
                 @empty_filter,
                 "grapefruit",
                 @pagination
               )
    end

    test "excludes a comment on an image carrying a hidden tag" do
      image = image_fixture(tags: "grimdark")
      tag = Enum.find(image.tags, &(&1.name == "grimdark"))
      _comment = comment_fixture(image, nil, %{"body" => "Test grapefruit comment"})
      SearchHelpers.reindex_all!(Comment)

      hidden_filter = %Filter{hidden_tag_ids: [tag.id]}

      assert {:ok, results} =
               Comments.query_comments(actor(), hidden_filter, "grapefruit", @pagination)

      assert results.entries == []

      # The same comment is visible when the tag is not hidden.
      assert {:ok, results} =
               Comments.query_comments(actor(), @empty_filter, "grapefruit", @pagination)

      assert [_entry] = results.entries
    end
  end

  describe "show_comment/2 visibility matrix" do
    test "loads hidden comments and normalizes destroyed, pending, and hidden-parent rows" do
      author = confirmed_user_fixture()
      user = confirmed_user_fixture()
      moderator = moderator_user_fixture()
      comment_assistant = role_assistant_fixture("Comment")

      visible_image = image_fixture()
      visible_comment = comment_fixture(visible_image)
      hidden_comment = already_hidden_comment(visible_image)
      pending = pending_comment(visible_image, author)

      destroyed =
        visible_image
        |> already_hidden_comment()
        |> Ecto.Changeset.change(destroyed_content: true)
        |> Repo.update!()

      hidden_image = image_fixture(hidden_from_users: true)
      parent_hidden_comment = comment_fixture(hidden_image, moderator)

      for viewer <- [actor(), actor(user), actor(moderator), actor(comment_assistant)] do
        assert Comments.show_comment(viewer, "not-an-id") == {:error, :not_found}
        assert Comments.show_comment(viewer, "2147483647") == {:error, :not_found}
        assert Comments.show_comment(viewer, destroyed.id) == {:error, :not_found}

        assert {:ok, %{id: id}} = Comments.show_comment(viewer, visible_comment.id)
        assert id == visible_comment.id

        assert {:ok, %{id: id}} = Comments.show_comment(viewer, hidden_comment.id)
        assert id == hidden_comment.id
      end

      for viewer <- [actor(), actor(user)] do
        assert Comments.show_comment(viewer, pending.id) == {:error, :not_found}
      end

      for viewer <- [actor(author), actor(moderator), actor(comment_assistant)] do
        assert {:ok, %{id: id}} = Comments.show_comment(viewer, pending.id)
        assert id == pending.id
      end

      for viewer <- [actor(), actor(user), actor(comment_assistant)] do
        assert Comments.show_comment(viewer, parent_hidden_comment.id) ==
                 {:error, :unauthorized}
      end

      assert {:ok, %{id: id}} = Comments.show_comment(actor(moderator), parent_hidden_comment.id)
      assert id == parent_hidden_comment.id
    end
  end

  # A comment authored by a fresh (untrusted) user containing an external link
  # is not auto-approved on creation (see Philomena.Schema.Approval); returns the
  # comment together with its author so the comments_count bump can be checked.
  defp unapproved_comment(image) do
    approval_rule!()
    author = confirmed_user_fixture()

    comment =
      comment_fixture(image, author, %{"body" => "check this out https://spam.example/"})

    refute comment.approved
    {comment, author}
  end

  defp approval_rule! do
    rule_fixture()
    |> Ecto.Changeset.change(name: "Approval")
    |> Repo.update!()
  end

  defp no_moderation_logs! do
    assert Repo.aggregate(ModerationLog, :count) == 0
  end

  defp force_filter_for_image(user, image) do
    filter = system_filter_fixture(hidden_complex_str: "id:#{image.id}")

    user
    |> Ecto.Changeset.change(forced_filter_id: filter.id)
    |> Repo.update!()
  end

  describe "create_comment_approve/3" do
    setup do
      %{image: image_fixture()}
    end

    test "denies an anonymous actor", %{image: image} do
      {comment, _author} = unapproved_comment(image)

      assert Comments.create_comment_approve(actor(), "#{image.id}", "#{comment.id}") ==
               {:error, :unauthorized}

      refute Repo.reload!(comment).approved
      no_moderation_logs!()
    end

    test "denies a regular user", %{image: image} do
      {comment, _author} = unapproved_comment(image)

      assert Comments.create_comment_approve(
               actor(confirmed_user_fixture()),
               "#{image.id}",
               "#{comment.id}"
             ) ==
               {:error, :unauthorized}

      refute Repo.reload!(comment).approved
      no_moderation_logs!()
    end

    test "a moderator approves the comment, which is returned approved", %{image: image} do
      {comment, _author} = unapproved_comment(image)
      moderator = moderator_user_fixture()

      assert {:ok, %Comment{} = approved} =
               Comments.create_comment_approve(actor(moderator), "#{image.id}", "#{comment.id}")

      assert approved.id == comment.id
      assert approved.approved

      assert Repo.reload!(comment).approved
    end

    test "the moderation log names the image and comment exactly", %{image: image} do
      {comment, _author} = unapproved_comment(image)
      moderator = moderator_user_fixture()

      assert {:ok, _} =
               Comments.create_comment_approve(actor(moderator), "#{image.id}", "#{comment.id}")

      log = Repo.one!(ModerationLog)
      assert log.user_id == moderator.id
      assert log.type == "Image.Comment.Approve:create"
      assert log.body == "Approved comment on image #{image.id}"
      assert log.subject_path == "/images/#{image.id}#comment_#{comment.id}"
    end

    test "approving increments the author's comments_count by one", %{image: image} do
      {comment, author} = unapproved_comment(image)
      before = Repo.get!(User, author.id).comments_count

      assert {:ok, _} =
               Comments.create_comment_approve(
                 actor(moderator_user_fixture()),
                 "#{image.id}",
                 "#{comment.id}"
               )

      assert Repo.get!(User, author.id).comments_count == before + 1
    end

    test "approving closes the comment's open reports", %{image: image} do
      {comment, _author} = unapproved_comment(image)
      report = report_fixture(confirmed_user_fixture(), comment_id: comment.id)

      assert report.open
      assert report.state == "open"

      assert {:ok, _} =
               Comments.create_comment_approve(
                 actor(moderator_user_fixture()),
                 "#{image.id}",
                 "#{comment.id}"
               )

      closed = Repo.get!(Report, report.id)
      refute closed.open
      assert closed.state == "closed"
    end

    # Repeated approval fails and does not increment the author's count a second time.
    test "approving an already-approved comment fails", %{image: image} do
      author = confirmed_user_fixture()
      comment = comment_fixture(image, author, %{"body" => "A perfectly ordinary comment"})
      assert comment.approved

      before = Repo.get!(User, author.id).comments_count

      assert {:error, _changeset} =
               Comments.create_comment_approve(
                 actor(moderator_user_fixture()),
                 "#{image.id}",
                 "#{comment.id}"
               )

      assert Repo.get!(User, author.id).comments_count == before
      refute Repo.exists?(ModerationLog)
    end

    test "a well-formed id naming no row is not found", %{image: image} do
      assert Comments.create_comment_approve(
               actor(moderator_user_fixture()),
               image.id,
               "999999999"
             ) == {:error, :not_found}

      no_moderation_logs!()
    end

    test "an id that cannot name a row is not found", %{image: image} do
      assert Comments.create_comment_approve(actor(moderator_user_fixture()), image.id, "abc") ==
               {:error, :not_found}

      no_moderation_logs!()
    end
  end

  # A visible comment authored by a fresh user, ready to be destroyed.
  defp visible_comment(image) do
    comment_fixture(image, confirmed_user_fixture(), %{"body" => "Rule-breaking comment"})
  end

  # An already-hidden comment, set up so no moderation log exists
  # before the destroy under test runs.
  defp already_hidden_comment(image) do
    {:ok, hidden} =
      Comments.create_comment_hide(
        actor(moderator_user_fixture()),
        image.id,
        visible_comment(image).id,
        %{"deletion_reason" => "Spam"}
      )

    Repo.delete_all(ModerationLog)

    hidden
  end

  describe "create_comment_delete/3" do
    setup do
      %{image: image_fixture()}
    end

    test "denies an anonymous actor, leaving the body intact", %{image: image} do
      comment = visible_comment(image)

      assert Comments.create_comment_delete(actor(), image.id, comment.id) ==
               {:error, :unauthorized}

      reloaded = Repo.reload!(comment)
      assert reloaded.body == "Rule-breaking comment"
      refute reloaded.destroyed_content
      no_moderation_logs!()
    end

    test "denies a regular user, leaving the body intact", %{image: image} do
      comment = visible_comment(image)

      assert Comments.create_comment_delete(actor(confirmed_user_fixture()), image.id, comment.id) ==
               {:error, :unauthorized}

      reloaded = Repo.reload!(comment)
      assert reloaded.body == "Rule-breaking comment"
      refute reloaded.destroyed_content
      no_moderation_logs!()
    end

    test "a moderator destroys the comment, emptying its body", %{image: image} do
      comment = already_hidden_comment(image)
      moderator = moderator_user_fixture()

      assert {:ok, %Comment{} = destroyed} =
               Comments.create_comment_delete(actor(moderator), image.id, comment.id)

      assert destroyed.id == comment.id

      # The destroy engine blanks the body and marks the content destroyed. It
      # requires but does not touch the comment's hidden/deletion_reason fields.
      reloaded = Repo.reload!(comment)
      assert reloaded.body == ""
      assert reloaded.destroyed_content
      assert reloaded.hidden_from_users
      assert reloaded.deletion_reason == "Spam"
    end

    test "destroys an already-hidden comment, keeping its hidden flag and reason",
         %{image: image} do
      comment = already_hidden_comment(image)

      no_moderation_logs!()

      assert {:ok, %Comment{}} =
               Comments.create_comment_delete(
                 actor(moderator_user_fixture()),
                 image.id,
                 comment.id
               )

      reloaded = Repo.reload!(comment)
      assert reloaded.body == ""
      assert reloaded.destroyed_content
      assert reloaded.hidden_from_users
      assert reloaded.deletion_reason == "Spam"

      assert {:error, %Ecto.Changeset{} = changeset} =
               Comments.create_comment_delete(
                 actor(moderator_user_fixture()),
                 image.id,
                 comment.id
               )

      reloaded = Repo.reload!(comment)
      assert %{destroyed_content: ["has already been destroyed"]} = errors_on(changeset)
      assert reloaded.body == ""
      assert reloaded.destroyed_content
      assert reloaded.hidden_from_users
      assert reloaded.deletion_reason == "Spam"
    end

    test "fails to destroy a visible comment", %{image: image} do
      comment = visible_comment(image)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Comments.create_comment_delete(actor(admin_user_fixture()), image.id, comment.id)

      no_moderation_logs!()

      reloaded = Repo.reload!(comment)

      assert %{destroyed_content: ["cannot be set while comment is visible"]} =
               errors_on(changeset)

      refute reloaded.body == ""
      refute reloaded.destroyed_content
      refute reloaded.hidden_from_users
      refute reloaded.deletion_reason == "Spam"
    end

    test "the moderation log names the image and comment exactly", %{image: image} do
      comment = already_hidden_comment(image)
      moderator = moderator_user_fixture()

      assert {:ok, _} = Comments.create_comment_delete(actor(moderator), image.id, comment.id)

      log = Repo.one!(ModerationLog)
      assert log.user_id == moderator.id
      assert log.type == "Image.Comment.Delete:create"
      assert log.body == "Destroyed comment on image #{image.id}"
      assert log.subject_path == "/images/#{image.id}#comment_#{comment.id}"
    end

    test "destroying decrements the author's comments_count by one", %{image: image} do
      author = confirmed_user_fixture()
      comment = comment_fixture(image, author, %{"body" => "Rule-breaking comment"})
      before = Repo.get!(User, author.id).comments_count

      assert {:ok, _} =
               Comments.create_comment_hide(
                 actor(moderator_user_fixture()),
                 image.id,
                 comment.id,
                 %{
                   "deletion_reason" => "spam"
                 }
               )

      assert {:ok, _} =
               Comments.create_comment_delete(
                 actor(moderator_user_fixture()),
                 image.id,
                 comment.id
               )

      assert Repo.get!(User, author.id).comments_count == before - 1
    end

    test "destroying a withheld comment does not decrement the author's comments_count",
         %{image: image} do
      {comment, author} = unapproved_comment(image)
      before = Repo.get!(User, author.id).comments_count

      refute comment.approved

      assert {:ok, _} =
               Comments.create_comment_hide(
                 actor(moderator_user_fixture()),
                 image.id,
                 comment.id,
                 %{"deletion_reason" => "Spam"}
               )

      assert {:ok, _} =
               Comments.create_comment_delete(
                 actor(moderator_user_fixture()),
                 image.id,
                 comment.id
               )

      assert Repo.get!(User, author.id).comments_count == before
    end

    test "a well-formed id naming no row is not found", %{image: image} do
      assert Comments.create_comment_delete(
               actor(moderator_user_fixture()),
               image.id,
               "999999999"
             ) == {:error, :not_found}

      no_moderation_logs!()
    end

    test "an id that cannot name a row is not found", %{image: image} do
      assert Comments.create_comment_delete(actor(moderator_user_fixture()), image.id, "abc") ==
               {:error, :not_found}

      no_moderation_logs!()
    end
  end

  describe "create_comment_hide/4" do
    setup do
      %{image: image_fixture()}
    end

    test "denies an anonymous actor, leaving the comment visible", %{image: image} do
      comment = visible_comment(image)

      assert Comments.create_comment_hide(actor(), image.id, comment.id, %{
               "deletion_reason" => "Spam"
             }) ==
               {:error, :unauthorized}

      refute Repo.reload!(comment).hidden_from_users
      no_moderation_logs!()
    end

    test "denies a regular user, leaving the comment visible", %{image: image} do
      comment = visible_comment(image)

      assert Comments.create_comment_hide(
               actor(confirmed_user_fixture()),
               image.id,
               comment.id,
               %{"deletion_reason" => "Spam"}
             ) ==
               {:error, :unauthorized}

      reloaded = Repo.reload!(comment)
      refute reloaded.hidden_from_users
      assert reloaded.deletion_reason == ""
      no_moderation_logs!()
    end

    test "a moderator hides the comment with the given reason", %{image: image} do
      comment = visible_comment(image)
      moderator = moderator_user_fixture()

      assert {:ok, %Comment{} = hidden} =
               Comments.create_comment_hide(actor(moderator), image.id, comment.id, %{
                 "deletion_reason" => "Spam"
               })

      assert hidden.id == comment.id
      assert hidden.hidden_from_users
      assert hidden.deletion_reason == "Spam"

      reloaded = Repo.reload!(comment)
      assert reloaded.hidden_from_users
      assert reloaded.deletion_reason == "Spam"
    end

    test "the moderation log names the image, comment, and reason exactly", %{image: image} do
      comment = visible_comment(image)
      moderator = moderator_user_fixture()

      assert {:ok, _} =
               Comments.create_comment_hide(actor(moderator), image.id, comment.id, %{
                 "deletion_reason" => "Spam"
               })

      log = Repo.one!(ModerationLog)
      assert log.user_id == moderator.id
      assert log.type == "Image.Comment.Hide:create"
      assert log.body == "Deleted comment on image #{image.id} (Spam)"
      assert log.subject_path == "/images/#{image.id}#comment_#{comment.id}"
    end

    test "a blank deletion reason is a rejected changeset carrying the loaded comment",
         %{image: image} do
      comment = visible_comment(image)

      assert {:error, %Ecto.Changeset{data: %Comment{} = returned}} =
               Comments.create_comment_hide(
                 actor(moderator_user_fixture()),
                 image.id,
                 comment.id,
                 %{
                   "deletion_reason" => ""
                 }
               )

      assert returned.id == comment.id
      refute Repo.reload!(comment).hidden_from_users
      no_moderation_logs!()
    end

    test "a well-formed id naming no row is not found", %{image: image} do
      assert Comments.create_comment_hide(
               actor(moderator_user_fixture()),
               image.id,
               "999999999",
               %{"deletion_reason" => "Spam"}
             ) == {:error, :not_found}

      no_moderation_logs!()
    end

    test "an id that cannot name a row is not found", %{image: image} do
      assert Comments.create_comment_hide(actor(moderator_user_fixture()), image.id, "abc", %{
               "deletion_reason" => "Spam"
             }) ==
               {:error, :not_found}

      no_moderation_logs!()
    end
  end

  describe "delete_comment_hide/3" do
    setup do
      %{image: image_fixture()}
    end

    test "denies an anonymous actor, leaving the comment hidden", %{image: image} do
      comment = already_hidden_comment(image)

      assert Comments.delete_comment_hide(actor(), image.id, comment.id) ==
               {:error, :unauthorized}

      assert Repo.reload!(comment).hidden_from_users
      no_moderation_logs!()
    end

    test "denies a regular user, leaving the comment hidden", %{image: image} do
      comment = already_hidden_comment(image)

      assert Comments.delete_comment_hide(actor(confirmed_user_fixture()), image.id, comment.id) ==
               {:error, :unauthorized}

      reloaded = Repo.reload!(comment)
      assert reloaded.hidden_from_users
      assert reloaded.deletion_reason == "Spam"
      no_moderation_logs!()
    end

    test "a moderator restores the comment, clearing its hidden flag and reason",
         %{image: image} do
      comment = already_hidden_comment(image)
      moderator = moderator_user_fixture()

      assert {:ok, %Comment{} = restored} =
               Comments.delete_comment_hide(actor(moderator), image.id, comment.id)

      assert restored.id == comment.id
      refute restored.hidden_from_users
      assert restored.deletion_reason == ""

      reloaded = Repo.reload!(comment)
      refute reloaded.hidden_from_users
      assert reloaded.deletion_reason == ""
    end

    test "the moderation log names the image and comment exactly", %{image: image} do
      comment = already_hidden_comment(image)
      moderator = moderator_user_fixture()

      assert {:ok, _} = Comments.delete_comment_hide(actor(moderator), image.id, comment.id)

      log = Repo.one!(ModerationLog)
      assert log.user_id == moderator.id
      assert log.type == "Image.Comment.Hide:delete"
      assert log.body == "Restored comment on image #{image.id}"
      assert log.subject_path == "/images/#{image.id}#comment_#{comment.id}"
    end

    # The restore is an unconditional column write, so restoring a comment that
    # is not hidden succeeds and still writes a log.
    test "restoring a non-hidden comment succeeds and logs", %{image: image} do
      comment = visible_comment(image)
      refute comment.hidden_from_users

      assert {:ok, %Comment{} = restored} =
               Comments.delete_comment_hide(actor(moderator_user_fixture()), image.id, comment.id)

      refute restored.hidden_from_users

      log = Repo.one!(ModerationLog)
      assert log.type == "Image.Comment.Hide:delete"
      assert log.body == "Restored comment on image #{image.id}"
    end

    test "a well-formed id naming no row is not found", %{image: image} do
      assert Comments.delete_comment_hide(actor(moderator_user_fixture()), image.id, "999999999") ==
               {:error, :not_found}

      no_moderation_logs!()
    end

    test "an id that cannot name a row is not found", %{image: image} do
      assert Comments.delete_comment_hide(actor(moderator_user_fixture()), image.id, "abc") ==
               {:error, :not_found}

      no_moderation_logs!()
    end
  end

  describe "list_comment_history/3" do
    # A public read routed by image id and comment id. It writes no moderation
    # log and runs no ban check; it authorizes :show on the image and, for a
    # hidden comment, :show on the comment.

    setup do
      %{image: image_fixture()}
    end

    test "an anonymous actor reads the history of a visible comment", %{image: image} do
      comment = comment_fixture(image, confirmed_user_fixture(), %{"body" => "A visible comment"})

      assert {:ok, %CommentHistory{} = history} =
               Comments.list_comment_history(actor(), "#{image.id}", "#{comment.id}")

      assert history.image.id == image.id
      assert history.comment.id == comment.id

      # The comment comes back with the associations the history page renders.
      assert %Philomena.Images.Image{} = history.comment.image
      assert %User{} = history.comment.user

      # A never-edited comment has recorded no versions.
      assert history.versions == []
    end

    test "an unknown image id is not found" do
      assert Comments.list_comment_history(actor(), "999999999", "1") == {:error, :not_found}
    end

    test "an unknown comment id on a real image is not found", %{image: image} do
      assert Comments.list_comment_history(actor(), "#{image.id}", "999999999") ==
               {:error, :not_found}
    end

    test "an anonymous actor cannot read the history of a hidden comment", %{image: image} do
      comment = already_hidden_comment(image)

      assert Comments.list_comment_history(actor(), "#{image.id}", "#{comment.id}") ==
               {:error, :unauthorized}
    end

    test "a regular user cannot read the history of a hidden comment", %{image: image} do
      comment = already_hidden_comment(image)

      assert Comments.list_comment_history(
               actor(confirmed_user_fixture()),
               "#{image.id}",
               "#{comment.id}"
             ) ==
               {:error, :unauthorized}
    end

    test "a moderator reads the history of a hidden comment", %{image: image} do
      comment = already_hidden_comment(image)

      assert {:ok, %CommentHistory{} = history} =
               Comments.list_comment_history(
                 actor(moderator_user_fixture()),
                 "#{image.id}",
                 "#{comment.id}"
               )

      assert history.comment.id == comment.id
      assert history.comment.hidden_from_users
      assert is_list(history.versions)
    end

    test "an edited comment reports the recorded version, its author, and the pre-edit body",
         %{image: image} do
      author = confirmed_user_fixture()
      comment = comment_fixture(image, author, %{"body" => "Original comment body"})

      {:ok, _} =
        Comments.update_comment(actor(author), image.id, comment.id, %{
          "body" => "Original comment body plus an edit",
          "edit_reason" => "typo fix"
        })

      assert {:ok, %CommentHistory{versions: [%CommentVersion{} = version]}} =
               Comments.list_comment_history(actor(), "#{image.id}", "#{comment.id}")

      # previous_body records the body as it stood before the edit, so the
      # single version carries the original text and names its editor.
      assert version.previous_body == "Original comment body"
      assert version.user.id == author.id
    end

    test "the history is capped at the most recent 25 versions", %{image: image} do
      author = confirmed_user_fixture()
      comment = comment_fixture(image, author, %{"body" => "edit 0"})

      # Each update records one version, so 26 edits record 26 versions; the
      # query limits the result to 25.
      Enum.reduce(1..26, comment, fn n, current ->
        {:ok, {_image, updated}} =
          Comments.update_comment(actor(author), image.id, current.id, %{"body" => "edit #{n}"})

        updated
      end)

      assert {:ok, %CommentHistory{versions: versions}} =
               Comments.list_comment_history(actor(), "#{image.id}", "#{comment.id}")

      assert length(versions) == 25
    end
  end

  describe "load_image/3" do
    # Loads and per-action authorizes the image a comment listing or write hangs
    # off. It accepts an Actor and runs no ban check.

    test ":index on a visible image succeeds for an anonymous actor" do
      image = image_fixture()

      assert {:ok, %Image{} = loaded} =
               Comments.load_image(actor(), "#{image.id}", :index)

      assert loaded.id == image.id

      # The listing preloads are loaded on the returned image.
      assert is_list(loaded.tags)
      assert is_list(loaded.sources)
    end

    test ":show on a visible image succeeds for an anonymous actor" do
      image = image_fixture()

      assert {:ok, %Image{} = loaded} =
               Comments.load_image(actor(), "#{image.id}", :show)

      assert loaded.id == image.id
    end

    test ":show on a hidden image is unauthorized for a regular user" do
      image = image_fixture(%{hidden_from_users: true})

      assert Comments.load_image(
               actor(confirmed_user_fixture()),
               "#{image.id}",
               :show
             ) ==
               {:error, :unauthorized}
    end

    test ":create/:edit/:update require create_comment, rejecting a commenting-disabled image" do
      image = image_fixture(%{commenting_allowed: false})
      user = confirmed_user_fixture()

      assert Comments.load_image(actor(user), "#{image.id}", :create_comment) ==
               {:error, :unauthorized}
    end

    test ":create_comment on a comment-enabled image succeeds for a regular user" do
      image = image_fixture()

      assert {:ok, %Image{} = loaded} =
               Comments.load_image(
                 actor(confirmed_user_fixture()),
                 "#{image.id}",
                 :create_comment
               )

      assert loaded.id == image.id
    end

    test "a well-formed id naming no row is not found" do
      assert Comments.load_image(actor(confirmed_user_fixture()), "999999999", :index) ==
               {:error, :not_found}
    end

    test "an id that cannot name a row is not found" do
      assert Comments.load_image(actor(confirmed_user_fixture()), "abc", :index) ==
               {:error, :not_found}
    end
  end

  describe "create_comment/3" do
    # A write taking an actor. It verifies write access first (ban -> :ban,
    # missing fingerprint -> :unauthorized), then authorizes the image.

    setup do
      %{image: image_fixture()}
    end

    test "a banned actor is rejected", %{image: image} do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Comments.create_comment(actor, image.id, %{"body" => "Hi"}) == {:error, :ban}
    end

    test "a forced-filter match is rejected before inserting", %{image: image} do
      user = force_filter_for_image(confirmed_user_fixture(), image)

      assert Comments.create_comment(actor(user), image.id, %{"body" => "Blocked"}) ==
               {:error, :forced_filter}

      assert Repo.aggregate(Comment, :count) == 0
    end

    test "an actor with no fingerprint is unauthorized, signed in or not", %{image: image} do
      signed_in = actor(confirmed_user_fixture(), fingerprint: nil)
      anonymous = actor(nil, fingerprint: nil)

      assert Comments.create_comment(signed_in, image.id, %{"body" => "Hi"}) ==
               {:error, :unauthorized}

      assert Comments.create_comment(anonymous, image.id, %{"body" => "Hi"}) ==
               {:error, :unauthorized}
    end

    test "a valid anonymous fingerprinted actor creates a comment with no author",
         %{image: image} do
      assert {:ok, %Comment{} = comment} =
               Comments.create_comment(actor(nil, ip: random_ip()), image.id, %{
                 "body" => "An anonymous comment"
               })

      assert comment.user_id == nil
      assert comment.body == "An anonymous comment"
      no_moderation_logs!()
    end

    test "a signed-in actor creates a comment attributed to the user", %{image: image} do
      user = confirmed_user_fixture()

      assert {:ok, %Comment{} = comment} =
               Comments.create_comment(actor(user), image.id, %{"body" => "A logged-in comment"})

      assert comment.user_id == user.id
      assert comment.body == "A logged-in comment"
      no_moderation_logs!()
    end

    test "an empty body is a creation failure, inserting nothing", %{image: image} do
      assert {:error, {_image, _changeset}} =
               Comments.create_comment(actor(confirmed_user_fixture()), image.id, %{"body" => ""})

      # The insert and its image comment-count bump are rolled back together.
      assert Repo.get!(Image, image.id).comments_count == 0
    end

    test "an untrusted author's link to this site stays approved", %{image: image} do
      [domain | _] = String.split(Application.get_env(:philomena, :site_domains), ",")

      assert {:ok, %Comment{} = comment} =
               Comments.create_comment(actor(confirmed_user_fixture()), image.id, %{
                 "body" => "see https://#{domain}/images/1"
               })

      assert comment.approved
    end

    test "an approved comment increments the author's comments_count by one", %{image: image} do
      author = confirmed_user_fixture()
      before = Repo.get!(User, author.id).comments_count

      assert {:ok, %Comment{} = comment} =
               Comments.create_comment(actor(author), image.id, %{
                 "body" => "A trustworthy comment"
               })

      assert comment.approved
      assert Repo.get!(User, author.id).comments_count == before + 1
    end

    test "a withheld comment does not increment the author's comments_count and is reported",
         %{image: image} do
      {comment, author} = unapproved_comment(image)
      before = Repo.get!(User, author.id).comments_count

      refute comment.approved
      assert Repo.get!(User, author.id).comments_count == before
      assert Repo.aggregate(from(r in Report, where: r.comment_id == ^comment.id), :count) == 1
    end

    test "an over-limit actor is rate limited and no comment is created", %{image: image} do
      # The :comment_create counter is primed past the limit, so the rate check
      # (after write-access, before the insert) refuses the write.
      actor = actor(confirmed_user_fixture())
      exceed_rate_limit(actor, :comment_create)

      assert Comments.create_comment(actor, image.id, %{"body" => "Hi"}) ==
               {:error, :rate_limited}

      # The comment and its image comment-count bump never happened.
      assert Repo.get!(Image, image.id).comments_count == 0
    end

    test "a successful create records the counter", %{image: image} do
      actor = actor(confirmed_user_fixture())
      track_rate_limit(actor, :comment_create)

      assert {:ok, %Comment{}} = Comments.create_comment(actor, image.id, %{"body" => "Hi"})
      assert rate_limit_count(actor, :comment_create) == "1"
    end

    test "an invalid comment does not consume the rate limit", %{image: image} do
      actor = actor(confirmed_user_fixture())
      exceed_rate_limit(actor, :comment_create)

      assert {:error, {%Image{}, %Ecto.Changeset{}}} =
               Comments.create_comment(actor, image.id, %{"body" => ""})

      assert rate_limit_count(actor, :comment_create) == "2"
    end
  end

  describe "show_comment/3" do
    setup do
      %{image: image_fixture()}
    end

    test "returns a visible comment with display preloads", %{image: image} do
      comment = comment_fixture(image, confirmed_user_fixture(), %{"body" => "A visible comment"})

      assert {:ok, {_image, %Comment{} = loaded}} =
               Comments.show_comment(actor(), image.id, "#{comment.id}")

      assert loaded.id == comment.id
      assert %User{} = loaded.user
    end

    test "an anonymous actor loads a hidden comment but not another user's pending one",
         %{image: image} do
      hidden = already_hidden_comment(image)
      pending = pending_comment(image)

      assert {:ok, {_image, %Comment{id: id, hidden_from_users: true}}} =
               Comments.show_comment(actor(), image.id, "#{hidden.id}")

      assert id == hidden.id
      assert Comments.show_comment(actor(), image.id, pending.id) == {:error, :not_found}
    end

    test "an unknown comment id is not found", %{image: image} do
      assert Comments.show_comment(actor(), image.id, "999999999") ==
               {:error, :not_found}
    end
  end

  describe "edit_comment/3" do
    # Backs the edit form, so it refuses bans before loading and authorizing
    # the comment for :edit.

    setup do
      %{image: image_fixture()}
    end

    test "a banned actor is rejected", %{image: image} do
      comment = comment_fixture(image, confirmed_user_fixture())
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Comments.edit_comment(actor, image.id, "#{comment.id}") == {:error, :ban}
    end

    test "the author loads the form, even without a fingerprint", %{image: image} do
      author = confirmed_user_fixture()
      comment = comment_fixture(image, author, %{"body" => "My comment"})

      assert {:ok, %Ecto.Changeset{} = changeset} =
               Comments.edit_comment(actor(author, fingerprint: nil), image.id, "#{comment.id}")

      assert changeset.data.id == comment.id

      # The changeset is over the loaded comment, driving the edit form.
      assert %Comment{} = changeset.data
      assert changeset.data.id == comment.id
    end

    test "the edit form rejects an image matching the author's forced filter", %{image: image} do
      user = confirmed_user_fixture()
      comment = comment_fixture(image, user)
      user = force_filter_for_image(user, image)

      assert Comments.edit_comment(actor(user), image.id, comment.id) ==
               {:error, :forced_filter}
    end

    test "another regular user cannot load the form", %{image: image} do
      comment = comment_fixture(image, confirmed_user_fixture())

      assert Comments.edit_comment(
               actor(confirmed_user_fixture()),
               image.id,
               "#{comment.id}"
             ) ==
               {:error, :unauthorized}
    end

    test "a moderator loads the form", %{image: image} do
      comment = comment_fixture(image, confirmed_user_fixture())

      assert {:ok, %Ecto.Changeset{} = changeset} =
               Comments.edit_comment(
                 actor(moderator_user_fixture()),
                 image.id,
                 "#{comment.id}"
               )

      assert changeset.data.id == comment.id
    end

    test "an unknown comment id is not found", %{image: image} do
      assert Comments.edit_comment(
               actor(confirmed_user_fixture()),
               image.id,
               "999999999"
             ) ==
               {:error, :not_found}
    end
  end

  describe "update_comment/4" do
    # A write, so it runs the write-access check first (ban -> :ban), then the
    # same load-and-authorize chain as the edit form, then the edit engine which
    # records a version.

    setup do
      %{image: image_fixture()}
    end

    test "a banned actor is rejected", %{image: image} do
      comment = comment_fixture(image, confirmed_user_fixture())
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Comments.update_comment(actor, image, "#{comment.id}", %{"body" => "Edited"}) ==
               {:error, :ban}
    end

    test "the author edits the body and the comment is marked edited", %{image: image} do
      author = confirmed_user_fixture()
      comment = comment_fixture(image, author, %{"body" => "Original comment body"})

      assert {:ok, {_image, %Comment{} = updated}} =
               Comments.update_comment(actor(author), image.id, "#{comment.id}", %{
                 "body" => "Original comment body plus an edit",
                 "edit_reason" => "typo"
               })

      assert updated.body == "Original comment body plus an edit"
      assert updated.edited_at != nil

      reloaded = Repo.reload!(comment)
      assert reloaded.body == "Original comment body plus an edit"
      assert reloaded.edited_at != nil
      no_moderation_logs!()
    end

    test "editing an approved comment into a withheld one decrements its count once and reports it",
         %{image: image} do
      author = confirmed_user_fixture()
      comment = comment_fixture(image, author, %{"body" => "An ordinary comment"})
      before = Repo.get!(User, author.id).comments_count
      approval_rule!()

      assert {:ok, {_image, %Comment{approved: false}}} =
               Comments.update_comment(actor(author), image.id, comment.id, %{
                 "body" => "Now containing https://spam.example/"
               })

      assert Repo.get!(User, author.id).comments_count == before - 1
      assert Repo.aggregate(from(r in Report, where: r.comment_id == ^comment.id), :count) == 1

      assert {:ok, {_image, %Comment{approved: false}}} =
               Comments.update_comment(actor(author), image.id, comment.id, %{
                 "body" => "Still containing https://spam.example/"
               })

      assert Repo.get!(User, author.id).comments_count == before - 1
      assert Repo.aggregate(from(r in Report, where: r.comment_id == ^comment.id), :count) == 1

      assert {:ok, %Comment{approved: true}} =
               Comments.create_comment_approve(
                 actor(moderator_user_fixture()),
                 image.id,
                 comment.id
               )

      assert Repo.get!(User, author.id).comments_count == before
    end

    test "editing the external link out of a withheld comment approves it and restores its count",
         %{image: image} do
      {comment, author} = unapproved_comment(image)
      before = Repo.get!(User, author.id).comments_count

      assert {:ok, {_image, %Comment{approved: true}}} =
               Comments.update_comment(actor(author), image.id, comment.id, %{
                 "body" => "No links here"
               })

      assert Repo.get!(User, author.id).comments_count == before + 1
    end

    test "a forced-filter match prevents an update", %{image: image} do
      user = confirmed_user_fixture()
      comment = comment_fixture(image, user, %{"body" => "Original"})
      user = force_filter_for_image(user, image)

      assert Comments.update_comment(actor(user), image.id, comment.id, %{"body" => "Changed"}) ==
               {:error, :forced_filter}

      assert Repo.reload!(comment).body == "Original"
    end

    test "another regular user cannot edit, leaving the body unchanged", %{image: image} do
      comment =
        comment_fixture(image, confirmed_user_fixture(), %{"body" => "Original comment body"})

      assert Comments.update_comment(
               actor(confirmed_user_fixture()),
               image.id,
               "#{comment.id}",
               %{"body" => "Hijacked"}
             ) ==
               {:error, :unauthorized}

      assert Repo.reload!(comment).body == "Original comment body"
    end

    test "a moderator and a comment assistant edit another user's comment", %{image: image} do
      comment = comment_fixture(image, confirmed_user_fixture(), %{"body" => "Original"})

      for staff <- [moderator_user_fixture(), role_assistant_fixture("Comment")] do
        body = "Edited by #{staff.role}"

        assert {:ok, {_image, %Comment{body: ^body}}} =
                 Comments.update_comment(actor(staff), image.id, comment.id, %{"body" => body})

        assert Repo.reload!(comment).body == body
      end
    end

    test "a blank body is a rejected changeset carrying the loaded comment", %{image: image} do
      author = confirmed_user_fixture()
      comment = comment_fixture(image, author, %{"body" => "Original comment body"})

      assert {:error, %Ecto.Changeset{} = changeset} =
               Comments.update_comment(actor(author), image.id, "#{comment.id}", %{"body" => ""})

      assert changeset.data.id == comment.id
      assert Repo.reload!(comment).body == "Original comment body"
    end

    test "an unknown comment id is not found", %{image: image} do
      assert Comments.update_comment(
               actor(confirmed_user_fixture()),
               image,
               "999999999",
               %{"body" => "Edited"}
             ) ==
               {:error, :not_found}
    end
  end

  describe "load_report_target/3" do
    test "loads a visible comment through its image parent" do
      image = image_fixture()
      comment = comment_fixture(image)

      assert {:ok, loaded} =
               Comments.load_report_target(actor(), image.id, comment.id)

      assert loaded.id == comment.id
      assert loaded.image_id == image.id
    end

    test "normalizes malformed, missing, and mismatched IDs" do
      first_image = image_fixture()
      second_image = image_fixture()
      comment = comment_fixture(first_image)

      assert Comments.load_report_target(actor(), first_image.id, "bad") ==
               {:error, :not_found}

      assert Comments.load_report_target(actor(), first_image.id, "2147483647") ==
               {:error, :not_found}

      assert Comments.load_report_target(actor(), second_image.id, comment.id) ==
               {:error, :not_found}
    end

    test "rejects a hidden comment for a regular user" do
      image = image_fixture()
      comment = comment_fixture(image)

      hidden =
        comment
        |> Ecto.Changeset.change(hidden_from_users: true)
        |> Repo.update!()

      assert Comments.load_report_target(actor(confirmed_user_fixture()), image.id, hidden.id) ==
               {:error, :unauthorized}
    end
  end

  describe "parent-scoped request services" do
    test "reject every comment operation when the route image does not own the comment" do
      moderator = moderator_user_fixture()
      moderator_actor = actor(moderator)
      image = image_fixture()
      other_image = image_fixture()
      comment = comment_fixture(image, confirmed_user_fixture(), %{"body" => "Unchanged"})

      assert Comments.show_comment(moderator_actor, other_image, comment.id) ==
               {:error, :not_found}

      assert Comments.edit_comment(moderator_actor, other_image, comment.id) ==
               {:error, :not_found}

      assert Comments.update_comment(
               moderator_actor,
               other_image,
               comment.id,
               %{"body" => "Changed"}
             ) == {:error, :not_found}

      assert Comments.list_comment_history(moderator_actor, other_image.id, comment.id) ==
               {:error, :not_found}

      assert Comments.load_report_target(moderator_actor, other_image.id, comment.id) ==
               {:error, :not_found}

      assert Comments.create_comment_hide(
               moderator_actor,
               other_image.id,
               comment.id,
               %{"deletion_reason" => "Spam"}
             ) == {:error, :not_found}

      assert Comments.delete_comment_hide(moderator_actor, other_image.id, comment.id) ==
               {:error, :not_found}

      assert Comments.create_comment_delete(moderator_actor, other_image.id, comment.id) ==
               {:error, :not_found}

      assert Comments.create_comment_approve(moderator_actor, other_image.id, comment.id) ==
               {:error, :not_found}

      unchanged = Repo.reload!(comment)
      assert unchanged.body == "Unchanged"
      refute unchanged.hidden_from_users
      refute unchanged.destroyed_content
      assert Repo.aggregate(ModerationLog, :count) == 0
    end
  end

  describe "sequential comment erasure" do
    test "hides then destroys content, closes reports, and updates counters" do
      moderator = moderator_user_fixture()
      author = confirmed_user_fixture()
      image = image_fixture()
      comment = comment_fixture(image, author, %{"body" => "Personal content"})
      report = report_fixture(confirmed_user_fixture(), comment_id: comment.id)
      moderator_actor = actor(moderator)

      author
      |> Ecto.Changeset.change(comments_count: 1)
      |> Repo.update!()

      assert Repo.reload!(image).comments_count == 1

      assert {:ok, _hidden} =
               Comments.create_comment_hide(
                 moderator_actor,
                 image.id,
                 comment.id,
                 %{"deletion_reason" => "Site abuse"}
               )

      assert {:ok, erased} = Comments.create_comment_delete(moderator_actor, image.id, comment.id)
      assert erased.hidden_from_users
      assert erased.destroyed_content
      assert erased.body == ""
      assert erased.deletion_reason == "Site abuse"
      assert Repo.reload!(image).comments_count == 0
      assert Repo.reload!(author).comments_count == 0

      closed_report = Repo.reload!(report)
      refute closed_report.open
      assert closed_report.state == "closed"
      assert Repo.aggregate(ModerationLog, :count) == 2
    end
  end

  # Pulls the must_not exclusion list out of an unexecuted comment search
  # definition.
  defp must_not(definition), do: definition.body.query.bool.must_not

  describe "comment_search_definition/4" do
    test "an anonymous viewer excludes deleted, non-approved, and hidden-tag comments" do
      filter = %Filter{hidden_tag_ids: [7, 8]}
      definition = Comments.comment_search_definition(actor(), filter, %{match_all: %{}})

      assert definition.module == Comment
      assert definition.body.query.bool.must == %{match_all: %{}}
      assert definition.body.sort == %{created_at: :desc}

      filters = must_not(definition)
      assert %{term: %{approved: false}} in filters
      assert %{term: %{"image.approved" => false}} in filters
      assert %{term: %{hidden_from_users: true}} in filters
      assert %{term: %{"image.hidden_from_users" => true}} in filters
      assert %{term: %{destroyed_content: true}} in filters
      assert %{terms: %{"image.tag_ids" => [7, 8]}} in filters
    end

    test "an authorized moderator drops deleted and non-approved excludes by default" do
      moderator = moderator_user_fixture()
      filter = %Filter{hidden_tag_ids: [7]}

      filters =
        must_not(Comments.comment_search_definition(actor(moderator), filter, %{match_all: %{}}))

      assert filters == [%{terms: %{"image.tag_ids" => [7]}}]
    end

    test "show_hidden false keeps public excludes for an authorized moderator" do
      moderator = moderator_user_fixture()

      filters =
        must_not(
          Comments.comment_search_definition(
            actor(moderator),
            @empty_filter,
            %{match_all: %{}},
            show_hidden: false
          )
        )

      assert %{
               bool: %{
                 must: [%{term: %{approved: false}}],
                 must_not: [%{term: %{true_author_id: moderator.id}}]
               }
             } in filters

      assert %{term: %{"image.approved" => false}} in filters
      assert %{term: %{hidden_from_users: true}} in filters
    end

    test "passes pagination through to the search window" do
      definition =
        Comments.comment_search_definition(
          actor(),
          @empty_filter,
          %{match_all: %{}},
          pagination: %{page_number: 3, page_size: 10}
        )

      assert definition.page_number == 3
      assert definition.page_size == 10
      assert definition.body.from == 20
      assert definition.body.size == 10
    end
  end

  # Creates an approved comment on `image`, its created_at fixed to a distinct
  # second so listing order is deterministic under the second-precision column.
  defp comment_at(image, offset) do
    comment_fixture(image, confirmed_user_fixture(), %{"body" => "Comment #{offset}"})
    |> Ecto.Changeset.change(created_at: DateTime.add(~U[2024-01-01 00:00:00Z], offset, :second))
    |> Repo.update!()
  end

  defp pending_comment(image, user \\ nil) do
    comment_fixture(image, user || confirmed_user_fixture())
    |> Ecto.Changeset.change(approved: false)
    |> Repo.update!()
  end

  defp destroyed_comment(image) do
    comment_fixture(image, confirmed_user_fixture())
    |> Ecto.Changeset.change(destroyed_content: true)
    |> Repo.update!()
  end

  defp oldest_first_user do
    user = confirmed_user_fixture()

    settings =
      user.settings
      |> Ecto.Changeset.change(comments_newest_first: false)
      |> Repo.update!()

    %{user | settings: settings}
  end

  describe "list_image_comments/3" do
    setup do
      %{image: image_fixture()}
    end

    test "returns a Scrivener page ordered newest first by default", %{image: image} do
      c1 = comment_at(image, 1)
      c2 = comment_at(image, 2)
      c3 = comment_at(image, 3)

      page = Comments.list_image_comments(actor(nil), image, page: 1, page_size: 25)

      assert %Scrivener.Page{} = page
      assert Enum.map(page.entries, & &1.id) == [c3.id, c2.id, c1.id]
    end

    test "orders oldest first for a user who reads oldest first", %{image: image} do
      c1 = comment_at(image, 1)
      c2 = comment_at(image, 2)
      c3 = comment_at(image, 3)

      page =
        Comments.list_image_comments(actor(oldest_first_user()), image,
          page: 1,
          page_size: 25
        )

      assert Enum.map(page.entries, & &1.id) == [c1.id, c2.id, c3.id]
    end

    test "an anonymous viewer sees approved and hidden comments, not pending or destroyed ones",
         %{image: image} do
      approved = comment_fixture(image, confirmed_user_fixture())
      hidden = already_hidden_comment(image)
      _pending = pending_comment(image)
      _destroyed = destroyed_comment(image)

      page = Comments.list_image_comments(actor(nil), image, page: 1, page_size: 25)

      assert Enum.sort(Enum.map(page.entries, & &1.id)) == Enum.sort([approved.id, hidden.id])
    end

    test "a signed-in user additionally sees their own non-approved comments",
         %{image: image} do
      author = confirmed_user_fixture()
      approved = comment_fixture(image, confirmed_user_fixture())
      own_pending = pending_comment(image, author)
      others_pending = pending_comment(image)

      page = Comments.list_image_comments(actor(author), image, page: 1, page_size: 25)
      ids = Enum.map(page.entries, & &1.id)

      assert approved.id in ids
      assert own_pending.id in ids
      refute others_pending.id in ids
    end

    test "authorized moderators see destroyed and non-approved comments", %{image: image} do
      approved = comment_fixture(image, confirmed_user_fixture())
      pending = pending_comment(image)
      destroyed = destroyed_comment(image)

      page =
        Comments.list_image_comments(actor(moderator_user_fixture()), image,
          page: 1,
          page_size: 25
        )

      ids = Enum.map(page.entries, & &1.id)

      assert approved.id in ids
      assert pending.id in ids
      assert destroyed.id in ids
    end
  end

  describe "list_comment_page/4" do
    setup do
      image = image_fixture()

      %{
        image: image,
        c1: comment_at(image, 1),
        c2: comment_at(image, 2),
        c3: comment_at(image, 3)
      }
    end

    test "returns the page a comment falls on for a newest-first reader",
         %{image: image, c1: c1, c2: c2, c3: c3} do
      # Newest first, page size 2: c3 and c2 share page 1, c1 falls to page 2.
      assert {:ok, {_image, 1}} =
               Comments.list_comment_page(actor(), image.id, c3.id, page_size: 2)

      assert {:ok, {_image, 1}} =
               Comments.list_comment_page(actor(), image.id, c2.id, page_size: 2)

      assert {:ok, {_image, 2}} =
               Comments.list_comment_page(actor(), image.id, c1.id, page_size: 2)
    end

    test "honors an oldest-first reader's direction", %{image: image, c1: c1, c2: c2, c3: c3} do
      user = oldest_first_user()

      # Oldest first, page size 2: c1 and c2 share page 1, c3 falls to page 2.
      assert {:ok, {_image, 1}} =
               Comments.list_comment_page(actor(user), image.id, c1.id, page_size: 2)

      assert {:ok, {_image, 1}} =
               Comments.list_comment_page(actor(user), image.id, c2.id, page_size: 2)

      assert {:ok, {_image, 2}} =
               Comments.list_comment_page(actor(user), image.id, c3.id, page_size: 2)
    end

    test "returns not-found when the comment does not belong to the image", %{image: image} do
      foreign = comment_fixture(image_fixture(), confirmed_user_fixture())

      assert Comments.list_comment_page(actor(), image, foreign.id, page_size: 2) ==
               {:error, :not_found}
    end
  end

  describe "last_comment_page/3" do
    test "returns the last page of a populated listing" do
      image = image_fixture()
      for offset <- 1..3, do: comment_at(image, offset)

      assert Comments.last_comment_page(actor(), image, page_size: 2) == 2
    end

    test "returns page 1 for an empty listing" do
      assert Comments.last_comment_page(actor(), image_fixture(), page_size: 2) == 1
    end

    test "counts only the comments visible to the viewer" do
      image = image_fixture()
      comment_fixture(image, confirmed_user_fixture())
      pending_comment(image)

      assert Comments.last_comment_page(actor(), image, page_size: 1) == 1

      assert Comments.last_comment_page(actor(moderator_user_fixture()), image, page_size: 1) ==
               2
    end
  end
end
