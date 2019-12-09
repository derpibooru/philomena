defmodule PhilomenaWeb.DuplicateReport.AcceptController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.DuplicateReports

  plug PhilomenaWeb.CanaryMapPlug, create: :edit, delete: :edit
  plug :load_and_authorize_resource, model: DuplicateReport, id_name: "duplicate_report_id", persisted: true

  def create(conn, _params) do
    {:ok, _report} = DuplicateReports.accept_duplicate_report(conn.assigns.duplicate_report, conn.assigns.current_user)

    conn
    |> put_flash(:info, "Successfully accepted report.")
    |> redirect(external: conn.assigns.referrer)
  end
end