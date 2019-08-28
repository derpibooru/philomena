defmodule Philomena.DuplicateReportsTest do
  use Philomena.DataCase

  alias Philomena.DuplicateReports

  describe "duplicate_reports" do
    alias Philomena.DuplicateReports.DuplicateReport

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def duplicate_report_fixture(attrs \\ %{}) do
      {:ok, duplicate_report} =
        attrs
        |> Enum.into(@valid_attrs)
        |> DuplicateReports.create_duplicate_report()

      duplicate_report
    end

    test "list_duplicate_reports/0 returns all duplicate_reports" do
      duplicate_report = duplicate_report_fixture()
      assert DuplicateReports.list_duplicate_reports() == [duplicate_report]
    end

    test "get_duplicate_report!/1 returns the duplicate_report with given id" do
      duplicate_report = duplicate_report_fixture()
      assert DuplicateReports.get_duplicate_report!(duplicate_report.id) == duplicate_report
    end

    test "create_duplicate_report/1 with valid data creates a duplicate_report" do
      assert {:ok, %DuplicateReport{} = duplicate_report} = DuplicateReports.create_duplicate_report(@valid_attrs)
    end

    test "create_duplicate_report/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DuplicateReports.create_duplicate_report(@invalid_attrs)
    end

    test "update_duplicate_report/2 with valid data updates the duplicate_report" do
      duplicate_report = duplicate_report_fixture()
      assert {:ok, %DuplicateReport{} = duplicate_report} = DuplicateReports.update_duplicate_report(duplicate_report, @update_attrs)
    end

    test "update_duplicate_report/2 with invalid data returns error changeset" do
      duplicate_report = duplicate_report_fixture()
      assert {:error, %Ecto.Changeset{}} = DuplicateReports.update_duplicate_report(duplicate_report, @invalid_attrs)
      assert duplicate_report == DuplicateReports.get_duplicate_report!(duplicate_report.id)
    end

    test "delete_duplicate_report/1 deletes the duplicate_report" do
      duplicate_report = duplicate_report_fixture()
      assert {:ok, %DuplicateReport{}} = DuplicateReports.delete_duplicate_report(duplicate_report)
      assert_raise Ecto.NoResultsError, fn -> DuplicateReports.get_duplicate_report!(duplicate_report.id) end
    end

    test "change_duplicate_report/1 returns a duplicate_report changeset" do
      duplicate_report = duplicate_report_fixture()
      assert %Ecto.Changeset{} = DuplicateReports.change_duplicate_report(duplicate_report)
    end
  end
end
