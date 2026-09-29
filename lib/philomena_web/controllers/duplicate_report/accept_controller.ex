defmodule PhilomenaWeb.DuplicateReport.AcceptController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.DuplicateReports

  plug PhilomenaWeb.CanaryMapPlug, create: :edit, delete: :edit

  plug :load_and_authorize_resource,
    model: DuplicateReport,
    id_name: "duplicate_report_id",
    persisted: true,
    preload: [:image, :duplicate_of_image]

  def create(conn, _params) do
    report = conn.assigns.duplicate_report
    user = conn.assigns.current_user

    case DuplicateReports.accept_duplicate_report(report, user) do
      {:ok, %{duplicate_report: report, affected_duplicate_reports: reports}} ->
        conn
        |> moderation_log(details: &log_details/2, data: report)
        |> put_view(PhilomenaWeb.DuplicateReportView)
        |> render("_duplicate_reports.html",
          layout: false,
          duplicate_reports: DuplicateReports.display_preloads(reports)
        )

      _error ->
        conn
        |> put_flash(:error, "Failed to accept report! Maybe someone else already accepted it.")
        |> send_resp(:multiple_choices, "")
        |> halt()
    end
  end

  defp log_details(_action, report) do
    %{
      body:
        "Accepted duplicate report, merged #{report.image.id} into #{report.duplicate_of_image.id}",
      subject_path: ~p"/images/#{report.image}"
    }
  end
end
