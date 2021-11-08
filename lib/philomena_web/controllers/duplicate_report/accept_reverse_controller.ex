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
    report = conn.assigns.duplicate_report
    user = conn.assigns.current_user

    case DuplicateReports.accept_reverse_duplicate_report(report, user) do
      {:ok, report} ->
        conn
        |> put_flash(:info, "Successfully accepted report in reverse.")
        |> moderation_log(details: &log_details/3, data: report.duplicate_report)
        |> redirect(to: Routes.duplicate_report_path(conn, :index))

      _error ->
        conn
        |> put_flash(:error, "Failed to accept report! Maybe someone else already accepted it.")
        |> redirect(to: Routes.duplicate_report_path(conn, :index))
    end
  end

  defp log_details(conn, _action, report) do
    %{
      body: "Reverse-accepted duplicate report, merged #{report.image.id} into #{report.duplicate_of_image.id}",
      subject_path: Routes.image_path(conn, :show, report.image)
    }
  end
end
