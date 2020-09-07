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
    {:ok, _report} =
      DuplicateReports.claim_duplicate_report(
        conn.assigns.duplicate_report,
        conn.assigns.current_user
      )

    conn
    |> put_flash(:info, "Successfully claimed report.")
    |> redirect(to: Routes.duplicate_report_path(conn, :index))
  end

  def delete(conn, _params) do
    {:ok, _report} = DuplicateReports.unclaim_duplicate_report(conn.assigns.duplicate_report)

    conn
    |> put_flash(:info, "Successfully released report.")
    |> redirect(to: Routes.duplicate_report_path(conn, :index))
  end
end
