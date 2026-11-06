defmodule Philomena.DuplicateReportsTest do
  use Philomena.DataCase, async: true

  alias Philomena.DuplicateReports
  alias Philomena.DuplicateReports.Comparison
  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.DuplicateReports.SearchResult
  alias Philomena.Images.Image
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Repo

  import Philomena.AttributionFixtures
  import Philomena.DuplicateReportsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  @ban %{
    reason: "Rule #0",
    valid_until: ~U[3000-01-01 00:00:00Z],
    generated_ban_id: "U123456",
    type: "User"
  }
  @pagination %{page_number: 1, page_size: 25}

  defp only_moderation_log!, do: Repo.one!(ModerationLog)

  defp hide_image(image) do
    image
    |> Ecto.Changeset.change(hidden_from_users: true)
    |> Repo.update!()
  end

  describe "list_duplicate_reports/3" do
    test "sorts claimed reports first descending and last ascending" do
      moderator = actor(moderator_user_fixture())
      claimed = duplicate_report_fixture(image_fixture(), image_fixture())
      open = duplicate_report_fixture(image_fixture(), image_fixture())
      {:ok, _} = DuplicateReports.create_duplicate_report_claim(moderator, claimed.id)

      assert {:ok, page, _} =
               DuplicateReports.list_duplicate_reports(moderator, %{}, @pagination)

      assert Enum.map(page.entries, & &1.id) == [claimed.id, open.id]

      assert {:ok, page, _} =
               DuplicateReports.list_duplicate_reports(moderator, %{"sd" => "asc"}, @pagination)

      assert Enum.map(page.entries, & &1.id) == [open.id, claimed.id]

      assert {:ok, page, changeset} =
               DuplicateReports.list_duplicate_reports(
                 moderator,
                 %{"sd" => "invalid"},
                 @pagination
               )

      assert page.entries == []
      refute changeset.valid?
    end

    test "authorizes the index and applies the state selection" do
      open = duplicate_report_fixture(image_fixture(), image_fixture())
      rejected = duplicate_report_fixture(image_fixture(), image_fixture())
      moderator = actor(moderator_user_fixture())

      {:ok, _rejected} = DuplicateReports.create_duplicate_report_reject(moderator, rejected.id)

      assert {:ok, page, changeset} =
               DuplicateReports.list_duplicate_reports(moderator, %{}, @pagination)

      assert Enum.map(page.entries, & &1.id) == [open.id]
      assert changeset.valid?

      assert {:ok, page, changeset} =
               DuplicateReports.list_duplicate_reports(
                 moderator,
                 %{"states" => ["rejected"]},
                 @pagination
               )

      assert Enum.map(page.entries, & &1.id) == [rejected.id]
      assert changeset.valid?

      assert {:ok, _page, _changeset} =
               DuplicateReports.list_duplicate_reports(actor(), %{}, @pagination)

      assistant = %{
        assistant_user_fixture()
        | role_map: %{"DuplicateReport" => %{"moderator" => []}}
      }

      assert {:ok, _page, _changeset} =
               DuplicateReports.list_duplicate_reports(actor(assistant), %{}, @pagination)
    end

    test "blank states use the default and invalid states match nothing" do
      report = duplicate_report_fixture(image_fixture(), image_fixture())
      moderator = actor(moderator_user_fixture())

      assert {:ok, blank_page, blank_changeset} =
               DuplicateReports.list_duplicate_reports(
                 moderator,
                 %{"states" => ""},
                 @pagination
               )

      assert Enum.map(blank_page.entries, & &1.id) == [report.id]
      assert blank_changeset.valid?

      assert {:ok, invalid_page, invalid_changeset} =
               DuplicateReports.list_duplicate_reports(
                 moderator,
                 %{"states" => ["bogus"]},
                 @pagination
               )

      assert invalid_page.entries == []
      assert invalid_changeset.errors[:states]
    end

    test "preloads the reporter, modifier, and both images" do
      report = duplicate_report_fixture(image_fixture(), image_fixture())

      assert {:ok, %{entries: [loaded]}, _changeset} =
               DuplicateReports.list_duplicate_reports(
                 actor(moderator_user_fixture()),
                 %{},
                 @pagination
               )

      assert loaded.id == report.id
      assert Ecto.assoc_loaded?(loaded.user)
      assert Ecto.assoc_loaded?(loaded.modifier)
      assert Ecto.assoc_loaded?(loaded.image)
      assert Ecto.assoc_loaded?(loaded.duplicate_of_image)
    end
  end

  describe "show_duplicate_report/2" do
    test "loads a public report only when both images are visible" do
      source = image_fixture()
      target = image_fixture()
      report = duplicate_report_fixture(source, target)

      assert {:ok, loaded} = DuplicateReports.show_duplicate_report(actor(), report.id)
      assert loaded.image.id == source.id
      assert loaded.duplicate_of_image.id == target.id

      hide_image(target)

      assert DuplicateReports.show_duplicate_report(actor(), report.id) ==
               {:error, :unauthorized}

      assert {:ok, _loaded} =
               DuplicateReports.show_duplicate_report(
                 actor(moderator_user_fixture()),
                 report.id
               )
    end

    test "normalizes malformed and missing IDs before authorization" do
      for viewer <- [actor(), actor(confirmed_user_fixture()), actor(moderator_user_fixture())],
          id <- ["not-an-id", "2147483647", "99999999999999999999"] do
        assert DuplicateReports.show_duplicate_report(viewer, id) == {:error, :not_found}
      end
    end
  end

  describe "new_duplicate_report/2" do
    test "returns the image, all existing reports, and creation changeset" do
      image = image_fixture()
      visible_target = image_fixture()
      hidden_target = image_fixture()
      visible_report = duplicate_report_fixture(image, visible_target)
      hidden_report = duplicate_report_fixture(image, hidden_target)
      hide_image(hidden_target)

      assert {:ok, {loaded, reports, changeset}} =
               DuplicateReports.new_duplicate_report(actor(), image.id)

      assert loaded.id == image.id
      assert visible_report.id in Enum.map(reports, & &1.id)
      assert hidden_report.id in Enum.map(reports, & &1.id)
      assert changeset.data.image.id == image.id
    end

    test "the form refuses bans and invisible images but not a missing fingerprint" do
      image = image_fixture()

      assert DuplicateReports.new_duplicate_report(
               actor(confirmed_user_fixture(), ban: @ban),
               image.id
             ) == {:error, :ban}

      assert {:ok, _} =
               DuplicateReports.new_duplicate_report(
                 actor(confirmed_user_fixture(), fingerprint: nil),
                 image.id
               )

      hidden = hide_image(image_fixture())

      assert DuplicateReports.new_duplicate_report(actor(), hidden.id) ==
               {:error, :unauthorized}

      assert DuplicateReports.new_duplicate_report(actor(), "not-an-id") ==
               {:error, :not_found}
    end
  end

  describe "create_duplicate_report/4" do
    test "records the reporter and returns both loaded image associations" do
      user = confirmed_user_fixture()
      source = image_fixture()
      target = image_fixture()

      assert {:ok, report} =
               DuplicateReports.create_duplicate_report(
                 actor(user),
                 source.id,
                 target.id,
                 %{"reason" => "same image"}
               )

      assert report.user_id == user.id
      assert report.image.id == source.id
      assert report.duplicate_of_image.id == target.id
      assert report.reason == "same image"
    end

    test "returns a changeset for a same-image or overlong-reason report" do
      image = image_fixture()

      assert {:error, same_image} =
               DuplicateReports.create_duplicate_report(actor(), image.id, image.id, %{})

      assert same_image.errors[:image_id] == {"must be different from the target", []}
      assert same_image.data.image.id == image.id

      assert {:error, too_long} =
               DuplicateReports.create_duplicate_report(
                 actor(),
                 image.id,
                 image_fixture().id,
                 %{"reason" => String.duplicate("x", 251)}
               )

      assert too_long.errors[:reason]
    end

    test "loads each image safely and enforces visibility" do
      visible = image_fixture()
      hidden = hide_image(image_fixture())

      for {source_id, target_id} <- [
            {"not-an-id", visible.id},
            {visible.id, "not-an-id"},
            {"2147483647", visible.id},
            {visible.id, "2147483647"}
          ] do
        assert DuplicateReports.create_duplicate_report(
                 actor(),
                 source_id,
                 target_id,
                 %{}
               ) == {:error, :not_found}
      end

      assert DuplicateReports.create_duplicate_report(actor(), hidden.id, visible.id, %{}) ==
               {:error, :unauthorized}

      assert DuplicateReports.create_duplicate_report(actor(), visible.id, hidden.id, %{}) ==
               {:error, :unauthorized}
    end

    test "checks a ban before locators and accepts anonymous attribution" do
      source = image_fixture()
      target = image_fixture()

      assert DuplicateReports.create_duplicate_report(
               actor(confirmed_user_fixture(), ban: @ban, fingerprint: nil),
               "not-an-id",
               "not-an-id",
               %{}
             ) == {:error, :ban}

      assert {:ok, report} =
               DuplicateReports.create_duplicate_report(
                 actor(),
                 source.id,
                 target.id,
                 %{}
               )

      assert report.user_id == nil
    end
  end

  describe "moderation locator and authorization contract" do
    test "all transitions distinguish a forbidden row from malformed or missing IDs" do
      report = duplicate_report_fixture(image_fixture(), image_fixture())

      actions = [
        &DuplicateReports.create_duplicate_report_accept/2,
        &DuplicateReports.create_duplicate_report_accept_reverse/2,
        &DuplicateReports.create_duplicate_report_claim/2,
        &DuplicateReports.delete_duplicate_report_claim/2,
        &DuplicateReports.create_duplicate_report_reject/2
      ]

      for action <- actions do
        assert action.(actor(confirmed_user_fixture()), report.id) ==
                 {:error, :unauthorized}

        assert action.(actor(moderator_user_fixture()), "not-an-id") ==
                 {:error, :not_found}

        assert action.(actor(moderator_user_fixture()), "2147483647") ==
                 {:error, :not_found}
      end
    end

    test "all transitions enforce write access before report loading" do
      report = duplicate_report_fixture(image_fixture(), image_fixture())

      for action <- [
            &DuplicateReports.create_duplicate_report_accept/2,
            &DuplicateReports.create_duplicate_report_accept_reverse/2,
            &DuplicateReports.create_duplicate_report_claim/2,
            &DuplicateReports.delete_duplicate_report_claim/2,
            &DuplicateReports.create_duplicate_report_reject/2
          ] do
        assert action.(actor(moderator_user_fixture(), ban: @ban), report.id) ==
                 {:error, :ban}
      end
    end
  end

  describe "create_duplicate_report_accept/2" do
    test "atomically accepts, rejects competing reports, merges, and logs" do
      moderator = moderator_user_fixture()
      source = image_fixture()
      target = image_fixture()
      report = duplicate_report_fixture(source, target)
      other = duplicate_report_fixture(target, source)

      assert {:ok, result, affected_reports} =
               DuplicateReports.create_duplicate_report_accept(actor(moderator), report.id)

      assert result.state == "accepted"

      assert Map.new(affected_reports, &{&1.id, &1.state}) ==
               %{report.id => "accepted", other.id => "rejected"}

      assert Enum.all?(affected_reports, &Ecto.assoc_loaded?(&1.image.tags))
      refute Enum.any?(affected_reports, &Comparison.mergeable?/1)
      assert Repo.get!(DuplicateReport, other.id).state == "rejected"

      source = Repo.get!(Image, source.id)
      assert source.hidden_from_users
      assert source.duplicate_id == target.id

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "DuplicateReport.Accept:create"
      assert log.subject_path == "/images/#{source.id}"
      assert log.body == "Accepted duplicate report, merged #{source.id} into #{target.id}"
    end

    test "an already accepted report returns a changeset and writes no second log" do
      moderator = actor(moderator_user_fixture())
      report = duplicate_report_fixture(image_fixture(), image_fixture())

      assert {:ok, _report, _affected_reports} =
               DuplicateReports.create_duplicate_report_accept(moderator, report.id)

      assert {:error, changeset} =
               DuplicateReports.create_duplicate_report_accept(moderator, report.id)

      assert changeset.errors[:state] == {"must be open or claimed", []}
      assert Repo.aggregate(ModerationLog, :count) == 1
    end

    test "a hidden source or target rejects the merge and rolls back the audit log" do
      moderator = actor(moderator_user_fixture())

      for hidden_side <- [:source, :target] do
        source = image_fixture()
        target = image_fixture()
        report = duplicate_report_fixture(source, target)

        case hidden_side do
          :source -> hide_image(source)
          :target -> hide_image(target)
        end

        assert {:error, %Ecto.Changeset{}} =
                 DuplicateReports.create_duplicate_report_accept(moderator, report.id)

        assert Repo.get!(DuplicateReport, report.id).state == "open"
      end

      assert Repo.aggregate(ModerationLog, :count) == 0
    end
  end

  describe "create_duplicate_report_accept_reverse/2" do
    test "accepts an existing reverse report and returns both updated rows" do
      moderator = actor(moderator_user_fixture())
      source = image_fixture()
      target = image_fixture()
      original = duplicate_report_fixture(source, target)
      reverse = duplicate_report_fixture(target, source)

      assert {:ok, accepted, affected_reports} =
               DuplicateReports.create_duplicate_report_accept_reverse(moderator, original.id)

      assert accepted.id == reverse.id
      assert accepted.state == "accepted"

      assert Map.new(affected_reports, &{&1.id, &1.state}) ==
               %{original.id => "rejected", reverse.id => "accepted"}
    end

    test "inserts a fresh reverse report when the existing one was rejected" do
      moderator = actor(moderator_user_fixture())
      source = image_fixture()
      target = image_fixture()
      rejected = duplicate_report_fixture(target, source)
      {:ok, _rejected} = DuplicateReports.create_duplicate_report_reject(moderator, rejected.id)
      original = duplicate_report_fixture(source, target)

      assert {:ok, accepted, affected_reports} =
               DuplicateReports.create_duplicate_report_accept_reverse(moderator, original.id)

      assert accepted.id not in [rejected.id, original.id]
      assert accepted.state == "accepted"

      assert Map.new(affected_reports, &{&1.id, &1.state}) ==
               %{original.id => "rejected", accepted.id => "accepted"}

      assert Repo.get!(DuplicateReport, rejected.id).state == "rejected"
    end

    test "rejects the original, accepts the reverse report, merges, and logs" do
      moderator = moderator_user_fixture()
      source = image_fixture()
      target = image_fixture()
      original = duplicate_report_fixture(source, target)

      assert {:ok, result, affected_reports} =
               DuplicateReports.create_duplicate_report_accept_reverse(
                 actor(moderator),
                 original.id
               )

      assert Repo.get!(DuplicateReport, original.id).state == "rejected"
      assert result.image_id == target.id
      assert result.duplicate_of_image_id == source.id
      assert result.state == "accepted"

      assert Map.new(affected_reports, &{&1.id, &1.state}) ==
               %{original.id => "rejected", result.id => "accepted"}

      refute Enum.any?(affected_reports, &Comparison.mergeable?/1)

      target = Repo.get!(Image, target.id)
      assert target.hidden_from_users
      assert target.duplicate_id == source.id

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "DuplicateReport.AcceptReverse:create"
      assert log.subject_path == "/images/#{target.id}"

      assert log.body ==
               "Reverse-accepted duplicate report, merged #{target.id} into #{source.id}"
    end

    test "truncates a long reason before appending the reverse-accepted suffix" do
      moderator = moderator_user_fixture()
      source = image_fixture()
      target = image_fixture()
      reason = String.duplicate("x", 250)
      original = duplicate_report_fixture(source, target, nil, %{"reason" => reason})

      assert {:ok, reverse_report, _affected_reports} =
               DuplicateReports.create_duplicate_report_accept_reverse(
                 actor(moderator),
                 original.id
               )

      assert byte_size(reverse_report.reason) == 250
      assert String.ends_with?(reverse_report.reason, "\n(Reverse accepted)")
      assert String.starts_with?(reverse_report.reason, String.duplicate("x", 231))
    end
  end

  describe "claim and unclaim transitions" do
    test "claim and unclaim validate state and commit their audit logs" do
      moderator = moderator_user_fixture()
      staff_actor = actor(moderator)
      report = duplicate_report_fixture(image_fixture(), image_fixture())

      assert {:ok, claimed} =
               DuplicateReports.create_duplicate_report_claim(staff_actor, report.id)

      assert claimed.state == "claimed"
      assert claimed.modifier_id == moderator.id

      assert {:error, already_claimed} =
               DuplicateReports.create_duplicate_report_claim(staff_actor, report.id)

      assert already_claimed.errors[:state] == {"must be open", []}

      assert {:ok, released} =
               DuplicateReports.delete_duplicate_report_claim(staff_actor, report.id)

      assert released.state == "open"
      assert released.modifier_id == nil

      assert {:error, not_claimed} =
               DuplicateReports.delete_duplicate_report_claim(staff_actor, report.id)

      assert not_claimed.errors[:state] == {"must be claimed", []}

      assert Repo.aggregate(ModerationLog, :count) == 2
    end
  end

  describe "create_duplicate_report_reject/2" do
    test "rejects an active report and logs its direction" do
      moderator = moderator_user_fixture()
      source = image_fixture()
      target = image_fixture()
      report = duplicate_report_fixture(source, target)

      assert {:ok, rejected} =
               DuplicateReports.create_duplicate_report_reject(actor(moderator), report.id)

      assert rejected.state == "rejected"
      assert rejected.modifier_id == moderator.id

      log = only_moderation_log!()
      assert log.type == "DuplicateReport.Reject:create"
      assert log.body == "Rejected duplicate report (#{source.id} -> #{target.id})"

      assert {:error, changeset} =
               DuplicateReports.create_duplicate_report_reject(actor(moderator), report.id)

      assert changeset.errors[:state] == {"must be open or claimed", []}
      assert Repo.aggregate(ModerationLog, :count) == 1
    end
  end

  describe "reverse search boundary" do
    test "returns a named empty result and explicit validation errors" do
      assert {:ok, %SearchResult{images: nil, changeset: changeset}} =
               DuplicateReports.create_reverse_search(actor())

      assert changeset.valid?

      assert {:error, invalid} =
               DuplicateReports.create_reverse_search(actor(), %{"distance" => "invalid"}, nil)

      refute invalid.valid?
      assert invalid.errors[:distance]
      assert invalid.errors[:uploaded_image]
    end
  end

  describe "count_duplicate_reports/1" do
    test "returns the open count only to staff" do
      duplicate_report_fixture(image_fixture(), image_fixture())

      assert DuplicateReports.count_duplicate_reports(actor()) == nil
      assert DuplicateReports.count_duplicate_reports(actor(confirmed_user_fixture())) == nil
      assert DuplicateReports.count_duplicate_reports(actor(moderator_user_fixture())) == 1
    end
  end
end
