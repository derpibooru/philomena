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
    |> put_flash(:info, "Successfully claimed report.")
    |> moderation_log(details: &log_details/2, data: report)
    |> redirect(to: ~p"/duplicate_reports")
  end

  def delete(conn, _params) do
    {:ok, _report} = DuplicateReports.unclaim_duplicate_report(conn.assigns.duplicate_report)

    conn
    |> put_flash(:info, "Successfully released report.")
    |> moderation_log(details: &log_details/2)
    |> redirect(to: ~p"/duplicate_reports")
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
