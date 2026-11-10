defmodule Philomena.DuplicateReportsConcurrencyTest do
  use Philomena.ConcurrentDataCase

  alias Philomena.DuplicateReports
  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Repo

  import Philomena.AttributionFixtures
  import Philomena.DuplicateReportsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  test "concurrent claims assign the report once and write one audit log" do
    report = duplicate_report_fixture(image_fixture(), image_fixture())

    results =
      concurrently(
        for moderator <- [moderator_user_fixture(), moderator_user_fixture()] do
          fn -> DuplicateReports.create_duplicate_report_claim(actor(moderator), report.id) end
        end
      )

    assert Enum.count(results, &match?({:ok, %DuplicateReport{}}, &1)) == 1
    assert Enum.count(results, &match?({:error, %Ecto.Changeset{}}, &1)) == 1
    assert Repo.aggregate(ModerationLog, :count) == 1

    persisted = Repo.get!(DuplicateReport, report.id)
    assert persisted.state == "claimed"
    assert persisted.modifier_id
  end
end
