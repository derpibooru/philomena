defmodule Philomena.Reports.LegacyConverterTest do
  use Philomena.DataCase, async: false
  use Patch

  import Philomena.ImagesFixtures
  import Philomena.RulesFixtures

  alias Philomena.Multi
  alias Philomena.Reports
  alias Philomena.Reports.LegacyConverter
  alias Philomena.Reports.Report
  alias Philomena.Repo

  defp report_fixture(rule_name, reason) do
    {:ok, %{report: report}} =
      Multi.new()
      |> Reports.put_create_system_report(rule_name, reason, :image_id, image_fixture().id)
      |> Multi.transact()

    report
  end

  defp converted(report) do
    report = Repo.get!(Report, report.id)
    {report.rule_id, report.reason}
  end

  test "moves legacy categories onto their rules, keeps unknown ones and reindexes" do
    legacy = rule_fixture(name: "Legacy", hidden: true, internal: true)
    rule = rule_fixture(name: "Rule #0")
    other = rule_fixture(name: "Other (please explain)", hidden: true)
    approval = rule_fixture(name: "Approval", hidden: true, internal: true)

    multiline = report_fixture("Legacy", "Rule #0: Insults\nin two lines")
    explained = report_fixture("Legacy", "Other: See the description")
    system = report_fixture("Legacy", "Approval: Contains a link")
    blank = report_fixture("Legacy", "Rule #0:  ")
    unknown = report_fixture("Legacy", "Rule #42: Gone")
    structured = report_fixture("Rule #0", "Other: Already converted")

    spy(Exq)

    assert LegacyConverter.convert_reports!() == :ok

    reindexed = [multiline.id, explained.id, system.id, blank.id]
    reindex = [Exq, "indexing", Philomena.IndexWorker, ["Reports", "id", reindexed]]
    assert {:enqueue, reindex} in history(Exq)

    assert converted(multiline) == {rule.id, "Insults\nin two lines"}
    assert converted(explained) == {other.id, "See the description"}
    assert converted(system) == {approval.id, "Contains a link"}
    assert converted(blank) == {rule.id, "Rule #0:"}
    assert converted(unknown) == {legacy.id, "Rule #42: Gone"}
    assert converted(structured) == {rule.id, "Other: Already converted"}
  end
end
