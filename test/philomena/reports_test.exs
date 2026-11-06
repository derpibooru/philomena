defmodule Philomena.ReportsTest do
  use Philomena.DataCase, async: false

  @moduletag :search

  import Philomena.AttributionFixtures
  import Philomena.CommentsFixtures
  import Philomena.CommissionsFixtures
  import Philomena.ConversationsFixtures
  import Philomena.ForumsFixtures
  import Philomena.GalleriesFixtures
  import Philomena.ImagesFixtures
  import Philomena.ModNotesFixtures
  import Philomena.ReportsFixtures
  import Philomena.RulesFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Comments.Comment
  alias Philomena.Commissions.Commission
  alias Philomena.Conversations.Conversation
  alias Philomena.Galleries.Gallery
  alias Philomena.Images.Image
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Posts.Post
  alias Philomena.Multi
  alias Philomena.Repo
  alias Philomena.Reports
  alias Philomena.Reports.Report
  alias Philomena.Reports.ReportForm
  alias Philomena.Reports.ReportPage
  alias Philomena.Reports.SearchIndex
  alias Philomena.Users.User
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  @pagination %{page_number: 1, page_size: 25}

  @ban %{
    reason: "Rule #0",
    valid_until: ~U[3000-01-01 00:00:00Z],
    generated_ban_id: "U123456",
    type: "User"
  }

  setup do
    Search.clear_index!(Report)
    :ok
  end

  defp report_params(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      "reason" => "Test report reason",
      "user_agent" => "Test Browser/1.0"
    })
    |> Map.put_new_lazy("rule_id", fn -> rule_fixture().id end)
  end

  defp target_matrix do
    image = image_fixture()
    comment = comment_fixture(image)
    profile = confirmed_user_fixture()
    commission_owner = confirmed_user_fixture()
    commission = commission_fixture(commission_owner)
    conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())
    gallery = gallery_fixture(confirmed_user_fixture())
    forum = forum_fixture()
    topic = topic_fixture(forum, confirmed_user_fixture())
    post = hd(topic.posts)

    [
      {{:image, image.id}, Image, :image_id, image.id},
      {{:comment, image.id, comment.id}, Comment, :comment_id, comment.id},
      {{:post, forum.short_name, topic.slug, post.id}, Post, :post_id, post.id},
      {{:user, profile.slug}, User, :reported_user_id, profile.id},
      {{:commission, commission_owner.slug}, Commission, :commission_id, commission.id},
      {{:conversation, conversation.slug}, Conversation, :conversation_id, conversation.id},
      {{:gallery, gallery.id}, Gallery, :gallery_id, gallery.id}
    ]
  end

  describe "report form boundary" do
    test "new_report/2 returns a typed form for every reportable locator" do
      actor = actor(moderator_user_fixture())
      reportable_rule = rule_fixture()

      for {locator, schema, foreign_key, target_id} <- target_matrix() do
        assert {:ok, %ReportForm{target: target, changeset: changeset, rules: rules}} =
                 Reports.new_report(actor, locator)

        assert target.__struct__ == schema
        assert target.id == target_id
        assert %Report{} = changeset.data
        assert Map.fetch!(changeset.data, foreign_key) == target_id
        assert reportable_rule.id in Enum.map(rules, & &1.id)
        refute Enum.any?(rules, & &1.internal)
      end
    end

    test "both paths refuse bans first, only create requires a fingerprint" do
      locator = {:image, "not-an-id"}
      banned = actor(confirmed_user_fixture(), ban: @ban)
      no_fingerprint = actor(nil, fingerprint: nil)

      assert Reports.new_report(banned, locator) == {:error, :ban}
      assert Reports.create_report(banned, locator, report_params()) == {:error, :ban}

      assert Reports.new_report(no_fingerprint, locator) == {:error, :not_found}

      assert Reports.create_report(no_fingerprint, locator, report_params()) ==
               {:error, :unauthorized}
    end

    test "malformed and missing locators are not-found for every actor" do
      for actor <- [actor(nil), actor(confirmed_user_fixture()), actor(admin_user_fixture())] do
        assert Reports.new_report(actor, {:image, "invalid"}) == {:error, :not_found}
        assert Reports.new_report(actor, {:image, "2147483647"}) == {:error, :not_found}
        assert Reports.new_report(actor, {:gallery, "2147483647"}) == {:error, :not_found}
        assert Reports.new_report(actor, {:user, "missing-profile"}) == {:error, :not_found}

        assert Reports.new_report(actor, {:conversation, "missing-conversation"}) ==
                 {:error, :not_found}

        assert Reports.new_report(actor, {:commission, "missing-profile"}) ==
                 {:error, :not_found}

        assert Reports.new_report(actor, {:post, "missing-forum", "missing-topic", "1"}) ==
                 {:error, :not_found}
      end
    end

    test "forbidden real targets are unauthorized" do
      hidden = image_fixture(%{hidden_from_users: true})

      assert Reports.new_report(actor(confirmed_user_fixture()), {:image, hidden.id}) ==
               {:error, :unauthorized}

      conversation =
        conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

      assert Reports.new_report(
               actor(confirmed_user_fixture()),
               {:conversation, conversation.slug}
             ) == {:error, :unauthorized}
    end

    test "comment and post locators enforce their route parents" do
      first_image = image_fixture()
      second_image = image_fixture()
      comment = comment_fixture(first_image)

      assert Reports.new_report(actor(), {:comment, second_image.id, comment.id}) ==
               {:error, :not_found}

      first_forum = forum_fixture()
      second_forum = forum_fixture()
      topic = topic_fixture(first_forum)
      post = hd(topic.posts)

      assert Reports.new_report(
               actor(),
               {:post, second_forum.short_name, topic.slug, post.id}
             ) == {:error, :not_found}

      assert Reports.new_report(
               actor(),
               {:post, first_forum.short_name, topic.slug, "not-an-id"}
             ) == {:error, :not_found}
    end
  end

  describe "create_report/3" do
    test "creates and attributes every reportable target" do
      moderator = moderator_user_fixture()

      for {locator, _schema, foreign_key, target_id} <- target_matrix() do
        assert {:ok, %Report{} = report} =
                 Reports.create_report(actor(moderator), locator, report_params())

        assert report.user_id == moderator.id
        assert Map.fetch!(report, foreign_key) == target_id
      end
    end

    test "an anonymous report records IP and fingerprint attribution" do
      image = image_fixture()

      assert {:ok, report} =
               Reports.create_report(actor(nil), {:image, image.id}, report_params())

      assert is_nil(report.user_id)
      assert report.ip
      assert report.fingerprint
    end

    test "validation returns the loaded target in a ReportForm" do
      image = image_fixture()

      assert {:error,
              %ReportForm{target: %Image{id: image_id}, changeset: changeset, rules: rules}} =
               Reports.create_report(
                 actor(),
                 {:image, image.id},
                 report_params(%{"reason" => ""})
               )

      assert image_id == image.id
      refute changeset.valid?
      assert changeset.errors[:reason]
      assert Enum.any?(rules)
    end

    test "the target gate runs before the open-report limit" do
      user = confirmed_user_fixture()
      image = image_fixture()

      for _ <- 1..Reports.max_open_reports() do
        report_fixture(user, image_id: image.id)
      end

      assert Reports.create_report(actor(user), {:image, "missing"}, report_params()) ==
               {:error, :not_found}

      assert Reports.create_report(actor(user), {:image, image.id}, report_params()) ==
               {:error, :too_many_reports}
    end

    test "the anonymous limit is keyed by IP and staff use a named bypass ability" do
      image = image_fixture()

      for _ <- 1..Reports.max_open_reports() do
        report_fixture(image_id: image.id)
      end

      assert Reports.create_report(actor(), {:image, image.id}, report_params()) ==
               {:error, :too_many_reports}

      moderator = moderator_user_fixture()

      for _ <- 1..Reports.max_open_reports() do
        report_fixture(moderator, image_id: image.id)
      end

      assert {:ok, %Report{}} =
               Reports.create_report(actor(moderator), {:image, image.id}, report_params())
    end
  end

  describe "user and staff indexes" do
    test "list_user_reports/2 is actor-scoped" do
      user = confirmed_user_fixture()
      other = confirmed_user_fixture()
      image = image_fixture()
      own = report_fixture(user, image_id: image.id)
      _other = report_fixture(other, image_id: image.id)

      assert {:ok, page} = Reports.list_user_reports(actor(user), @pagination)
      assert Enum.map(page.entries, & &1.id) == [own.id]
      assert Reports.list_user_reports(actor(), @pagination) == {:error, :unauthorized}
    end

    test "count_open_reports/1 authorizes before querying" do
      assert Reports.count_open_reports(actor()) == nil
      assert Reports.count_open_reports(actor(confirmed_user_fixture())) == nil
      assert Reports.count_open_reports(actor(moderator_user_fixture())) == 0
    end

    test "list_reports/3 returns the assembled default page" do
      report = report_fixture(image_id: image_fixture().id)
      SearchHelpers.reindex_all!(Report)

      assert {:ok, %ReportPage{reports: reports, my_reports: [], system_reports: []},
              _query_changeset} =
               Reports.list_reports(actor(admin_user_fixture()), %{}, @pagination)

      assert report.id in Enum.map(reports.entries, & &1.id)
    end

    test "the search branch empties auxiliary lists and rejects malformed queries" do
      report_fixture(image_id: image_fixture().id)
      SearchHelpers.reindex_all!(Report)
      admin = actor(admin_user_fixture())

      assert {:ok, %ReportPage{reports: reports, my_reports: [], system_reports: []},
              _query_changeset} =
               Reports.list_reports(admin, %{"query" => "*"}, @pagination)

      assert length(reports.entries) == 1

      assert {:error, %Ecto.Changeset{}} =
               Reports.list_reports(admin, %{"query" => "("}, @pagination)

      assert {:error, %Ecto.Changeset{}} =
               Reports.list_reports(admin, %{"query" => ["open:true"]}, @pagination)
    end

    test "user_name_reindex/2 renames the report's related user" do
      target = confirmed_user_fixture()
      report = report_fixture(reported_user_id: target.id)
      SearchHelpers.reindex_all!(Report)
      admin = actor(admin_user_fixture())
      new_name = "Renamed#{target.id}"

      Reports.user_name_reindex(target.name, new_name)

      # The update runs asynchronously in the search engine; poll for up to 5 s.
      assert Enum.any?(1..250, fn _ ->
               Process.sleep(20)
               :ok = Search.refresh_index!(Report)

               {:ok, %ReportPage{reports: reports}, _changeset} =
                 Reports.list_reports(admin, %{"query" => "related:#{new_name}"}, @pagination)

               Enum.map(reports.entries, & &1.id) == [report.id]
             end)
    end

    test "the index is unauthorized for regular users" do
      assert Reports.list_reports(actor(), %{}, @pagination) == {:error, :unauthorized}

      assert Reports.list_reports(
               actor(confirmed_user_fixture()),
               %{},
               @pagination
             ) == {:error, :unauthorized}
    end
  end

  describe "show_report/2" do
    test "loads a real report with its target and normalizes missing IDs" do
      image = image_fixture()
      report = report_fixture(image_id: image.id)

      assert {:ok, loaded} = Reports.show_report(actor(moderator_user_fixture()), report.id)
      assert loaded.image.id == image.id

      for actor <- [actor(), actor(confirmed_user_fixture()), actor(moderator_user_fixture())] do
        assert Reports.show_report(actor, "not-an-id") == {:error, :not_found}
        assert Reports.show_report(actor, "2147483647") == {:error, :not_found}
      end

      assert Reports.show_report(actor(confirmed_user_fixture()), report.id) ==
               {:error, :unauthorized}
    end
  end

  describe "report transition changesets" do
    test "claim requires an open, unclaimed report" do
      moderator = moderator_user_fixture()

      closed = Report.claim_changeset(%Report{open: false}, moderator)
      claimed = Report.claim_changeset(%Report{open: true, admin_id: moderator.id}, moderator)

      refute closed.valid?
      assert closed.errors[:state] == {"must be open", []}
      refute claimed.valid?
      assert claimed.errors[:admin_id] == {"has already been claimed", []}
    end

    test "unclaim requires an open report and errors when not claimed" do
      moderator = moderator_user_fixture()

      closed = Report.unclaim_changeset(%Report{open: false, admin_id: moderator.id}, moderator)
      unclaimed = Report.unclaim_changeset(%Report{open: true, state: "open"}, moderator)

      refute closed.valid?
      assert closed.errors[:state] == {"must be open", []}
      refute unclaimed.valid?
      assert unclaimed.errors[:admin_id] == {"was not claimed", []}
    end

    test "close is invalid when the report is already closed" do
      report = %Report{open: false, state: "closed", admin_id: moderator_user_fixture().id}

      changeset = Report.close_changeset(report, moderator_user_fixture())

      refute changeset.valid?
    end
  end

  describe "staff transitions" do
    setup do
      %{report: report_fixture(image_id: image_fixture().id)}
    end

    test "claim commits its moderation log with the report", %{report: report} do
      moderator = moderator_user_fixture()
      assert {:ok, claimed} = Reports.create_report_claim(actor(moderator), report.id)
      assert claimed.state == "in_progress"
      assert claimed.admin_id == moderator.id

      log = Repo.one!(ModerationLog)
      assert log.user_id == moderator.id
      assert log.type == "Report.Claim:create"
      assert log.subject_path == "/admin/reports/#{report.id}"
    end

    test "unclaim releases a claim", %{report: report} do
      moderator = actor(moderator_user_fixture())
      assert {:ok, _claimed} = Reports.create_report_claim(moderator, report.id)
      assert {:ok, released} = Reports.delete_report_claim(moderator, report.id)
      assert released.state == "open"
      assert is_nil(released.admin_id)
      assert {:error, %Ecto.Changeset{}} = Reports.delete_report_claim(moderator, report.id)
      assert Repo.aggregate(ModerationLog, :count) == 2
    end

    test "close cannot be undone by unclaim", %{report: report} do
      moderator = actor(moderator_user_fixture())
      assert {:ok, closed} = Reports.create_report_close(moderator, report.id)
      refute closed.open
      assert closed.state == "closed"
      assert {:error, %Ecto.Changeset{}} = Reports.create_report_close(moderator, report.id)
      assert Repo.aggregate(ModerationLog, :count) == 1

      assert {:error, changeset} = Reports.delete_report_claim(moderator, report.id)
      assert changeset.errors[:state]
    end

    test "each action has a distinct authorization and stable ID contract", %{report: report} do
      user = actor(confirmed_user_fixture())

      for action <- [
            &Reports.create_report_claim/2,
            &Reports.delete_report_claim/2,
            &Reports.create_report_close/2
          ] do
        assert action.(user, report.id) == {:error, :unauthorized}
        assert action.(actor(moderator_user_fixture()), "not-an-id") == {:error, :not_found}

        assert action.(actor(moderator_user_fixture()), "2147483647") ==
                 {:error, :not_found}
      end
    end
  end

  describe "mod notes" do
    test "sensitive notes are returned only after the note authorization gate" do
      report = report_fixture(image_id: image_fixture().id)
      note = mod_note_fixture_for(moderator_user_fixture(), %{"report_id" => report.id})

      notes = Reports.mod_notes(actor(moderator_user_fixture()), report, & &1)
      assert note.id in Enum.map(notes, fn {loaded, _rendered} -> loaded.id end)
      assert Reports.mod_notes(actor(confirmed_user_fixture()), report, & &1) == nil
      assert Reports.mod_notes(actor(), report, & &1) == nil
    end
  end

  describe "trusted cross-context services" do
    test "bulk close returns IDs for after-commit indexing" do
      image = image_fixture()
      report = report_fixture(image_id: image.id)
      moderator = moderator_user_fixture()

      {:ok, _} =
        Multi.new()
        |> Reports.put_close_reports(:reports, moderator, image_id: image.id)
        |> Multi.transact()

      closed = Repo.get!(Report, report.id)
      refute closed.open
      assert closed.admin_id == moderator.id
    end

    test "system reports require a real rule" do
      image = image_fixture()
      rule = rule_fixture()

      {:ok, _} =
        Multi.new()
        |> Reports.put_create_system_report(rule.name, "Automated review", :image_id, image.id)
        |> Multi.transact()

      assert Repo.aggregate(where(Report, system: true), :count) == 1

      assert_raise(MatchError, fn ->
        Multi.new()
        |> Reports.put_create_system_report("missing rule", "reason", :image_id, image.id)
        |> Multi.transact()
      end)
    end
  end

  describe "target invariants and indexing" do
    test "target_columns/0 lists all reportable foreign keys" do
      assert Report.target_columns() == [
               :image_id,
               :comment_id,
               :post_id,
               :reported_user_id,
               :commission_id,
               :conversation_id,
               :gallery_id
             ]
    end

    test "the creation changeset rejects zero or multiple targets" do
      image = image_fixture()
      user = confirmed_user_fixture()
      attrs = %{"reason" => "bad target count", "user_agent" => "test"}
      rule = rule_fixture()

      zero = Report.creation_changeset(%Report{}, attrs, actor(), rule)

      two =
        Report.creation_changeset(
          %Report{image_id: image.id, reported_user_id: user.id},
          attrs,
          actor(),
          rule
        )

      assert %{target: ["must reference exactly one target"]} = errors_on(zero)
      assert %{target: ["must reference exactly one target"]} = errors_on(two)
    end

    test "orphaned reports preload and serialize without crashing" do
      {:ok, orphan} =
        %Report{}
        |> Ecto.Changeset.change(%{
          ip: %Postgrex.INET{address: {127, 0, 0, 1}, netmask: 32},
          fingerprint: "ffff",
          reason: "orphan"
        })
        |> Repo.insert()

      preloaded = Repo.preload(orphan, Reports.indexing_preloads())
      assert Enum.all?(Report.target_columns(), &is_nil(Map.get(preloaded, &1)))
      assert SearchIndex.as_json(preloaded).reportable_type == nil
    end

    test "indexed targets retain their legacy reportable fields" do
      image = image_fixture()
      report = report_fixture(image_id: image.id)
      indexed = Repo.preload(report, Reports.indexing_preloads()) |> SearchIndex.as_json()

      assert indexed.reportable_type == "Image"
      assert indexed.reportable_id == image.id
      assert indexed.image_id == image.id
    end
  end
end
