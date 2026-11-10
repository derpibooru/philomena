defmodule Philomena.ReportsConcurrencyTest do
  use Philomena.ConcurrentDataCase

  @moduletag :search

  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1, actor: 2, random_ip: 0]
  import Philomena.ImagesFixtures
  import Philomena.ReportsFixtures
  import Philomena.RulesFixtures
  import Philomena.UsersFixtures

  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Repo
  alias Philomena.Reports
  alias Philomena.Reports.Report
  alias PhilomenaQuery.Search

  setup do
    Search.clear_index!(Report)
    %{report: report_fixture(image_id: image_fixture().id)}
  end

  test "a second or racing claim cannot reassign the report", %{report: report} do
    results =
      concurrently(
        for moderator <- [moderator_user_fixture(), moderator_user_fixture()] do
          fn -> Reports.create_report_claim(actor(moderator), report.id) end
        end
      )

    assert Enum.count(results, &match?({:ok, %Report{}}, &1)) == 1
    assert Enum.count(results, &match?({:error, %Ecto.Changeset{}}, &1)) == 1
    assert Repo.aggregate(ModerationLog, :count) == 1
  end

  test "racing anonymous report creation cannot exceed the open report limit" do
    image = image_fixture()

    # The setup report uses the shared fixture IP, so leave one slot for the
    # racing requests after accounting for it.
    for _ <- 1..(Reports.max_open_reports() - 2) do
      report_fixture(image_id: image.id)
    end

    params = %{
      "reason" => "Concurrent test report",
      "user_agent" => "Test Browser/1.0",
      "rule_id" => rule_fixture().id
    }

    results =
      concurrently([
        fn -> Reports.create_report(actor(), {:image, image.id}, params) end,
        fn -> Reports.create_report(actor(), {:image, image.id}, params) end
      ])

    assert Enum.count(results, &match?({:ok, %Report{}}, &1)) == 1
    assert Enum.count(results, &(&1 == {:error, :too_many_reports})) == 1
    assert Repo.aggregate(Report, :count) == Reports.max_open_reports()
  end

  test "racing authenticated report creation cannot exceed the user limit" do
    user = confirmed_user_fixture()
    ip = random_ip()
    image = image_fixture()

    for _ <- 1..(Reports.max_open_reports() - 1) do
      {:ok, _report} =
        Reports.create_report(
          actor(user, ip: ip),
          {:image, image.id},
          %{
            "reason" => "Concurrent test report",
            "user_agent" => "Test Browser/1.0",
            "rule_id" => rule_fixture().id
          }
        )
    end

    params = %{
      "reason" => "Concurrent test report",
      "user_agent" => "Test Browser/1.0",
      "rule_id" => rule_fixture().id
    }

    results =
      concurrently(
        for racing_ip <- [random_ip(), random_ip()] do
          fn -> Reports.create_report(actor(user, ip: racing_ip), {:image, image.id}, params) end
        end
      )

    assert Enum.count(results, &match?({:ok, %Report{}}, &1)) == 1
    assert Enum.count(results, &(&1 == {:error, :too_many_reports})) == 1
    assert Repo.aggregate(Report, :count) == Reports.max_open_reports() + 1
  end
end
