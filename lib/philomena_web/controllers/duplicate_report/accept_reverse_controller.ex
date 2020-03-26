defmodule PhilomenaWeb.DuplicateReport.AcceptReverseController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.DuplicateReports
  alias Philomena.Reports
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, create: :edit, delete: :edit

  plug :load_and_authorize_resource,
    model: DuplicateReport,
    id_name: "duplicate_report_id",
    persisted: true,
    preload: [:image, :duplicate_of_image]

  def create(conn, _params) do
    {:ok, %{reports: {_count, reports}}} =
      DuplicateReports.accept_reverse_duplicate_report(
        conn.assigns.duplicate_report,
        conn.assigns.current_user
      )

    Reports.reindex_reports(reports)
    Images.reindex_image(conn.assigns.duplicate_report.image)
    Images.reindex_image(conn.assigns.duplicate_report.duplicate_of_image)

    conn
    |> put_flash(:info, "Successfully accepted report in reverse.")
    |> redirect(external: conn.assigns.referrer)
  end
end
