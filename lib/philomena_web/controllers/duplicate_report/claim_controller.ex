defmodule PhilomenaWeb.DuplicateReport.ClaimController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.DuplicateReports

  plug PhilomenaWeb.CanaryMapPlug, create: :edit, delete: :edit

  plug :load_and_authorize_resource,
    model: DuplicateReport,
    id_name: "duplicate_report_id",
    persisted: true

  def create(conn, _params) do
    {:ok, report} =
      DuplicateReports.claim_duplicate_report(
        conn.assigns.duplicate_report,
        conn.assigns.current_user
      )

    conn
    |> moderation_log(details: &log_details/2, data: report)
    |> put_view(PhilomenaWeb.DuplicateReportView)
    |> render("_duplicate_reports.html",
      layout: false,
      duplicate_reports: DuplicateReports.display_preloads([report])
    )
  end

  def delete(conn, _params) do
    {:ok, report} = DuplicateReports.unclaim_duplicate_report(conn.assigns.duplicate_report)

    conn
    |> moderation_log(details: &log_details/2)
    |> put_view(PhilomenaWeb.DuplicateReportView)
    |> render("_duplicate_reports.html",
      layout: false,
      duplicate_reports: DuplicateReports.display_preloads([report])
    )
  end

  defp log_details(action, _) do
    body =
      case action do
        :create -> "Claimed a duplicate report"
        :delete -> "Released a duplicate report"
      end

    %{
      body: body,
      subject_path: ~p"/duplicate_reports"
    }
  end
end
