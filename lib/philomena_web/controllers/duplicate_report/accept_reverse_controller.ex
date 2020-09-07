defmodule PhilomenaWeb.DuplicateReport.AcceptReverseController do
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
    {:ok, _report} =
      DuplicateReports.accept_reverse_duplicate_report(
        conn.assigns.duplicate_report,
        conn.assigns.current_user
      )

    conn
    |> put_flash(:info, "Successfully accepted report in reverse.")
    |> redirect(to: Routes.duplicate_report_path(conn, :index))
  end
end
