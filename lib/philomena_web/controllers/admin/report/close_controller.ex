defmodule PhilomenaWeb.Admin.Report.CloseController do
  use PhilomenaWeb, :controller

  alias Philomena.Reports.Report
  alias Philomena.Reports

  plug PhilomenaWeb.CanaryMapPlug, create: :edit, delete: :edit
  plug :load_and_authorize_resource, model: Report, id_name: "report_id", persisted: true

  def create(conn, _params) do
    {:ok, report} = Reports.close_report(conn.assigns.report, conn.assigns.current_user)
    Reports.reindex_report(report)

    conn
    |> put_flash(:info, "Successfully closed report")
    |> redirect(to: Routes.admin_report_path(conn, :index))
  end
end