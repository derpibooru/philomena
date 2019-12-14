defmodule PhilomenaWeb.Admin.Report.ClaimController do
  use PhilomenaWeb, :controller

  alias Philomena.Reports.Report
  alias Philomena.Reports

  plug PhilomenaWeb.CanaryMapPlug, create: :edit, delete: :edit
  plug :load_and_authorize_resource, model: Report, id_name: "report_id", persisted: true

  def create(conn, _params) do
    case Reports.claim_report(conn.assigns.report, conn.assigns.current_user) do
      {:ok, report} ->
        Reports.reindex_report(report)

        conn
        |> put_flash(:info, "Successfully marked report as in progress")
        |> redirect(to: Routes.admin_report_path(conn, :index))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Couldn't claim that report!")
        |> redirect(to: Routes.admin_report_path(conn, :show, conn.assigns.report))
    end
  end

  def delete(conn, _params) do
    {:ok, report} = Reports.unclaim_report(conn.assigns.report)
    Reports.reindex_report(report)

    conn
    |> put_flash(:info, "Successfully released report.")
    |> redirect(to: Routes.admin_report_path(conn, :show, report))
  end
end
