defmodule PhilomenaWeb.DuplicateReport.AcceptReverseController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"duplicate_report_id" => id}) do
    case DuplicateReports.create_duplicate_report_accept_reverse(conn.assigns.actor, id) do
      {:ok, _report, reports} ->
        conn
        |> put_view(PhilomenaWeb.DuplicateReportView)
        |> render("_duplicate_reports.html", layout: false, duplicate_reports: reports)

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Failed to accept report! Maybe someone else already accepted it.")
        |> send_resp(:multiple_choices, "")
        |> halt()

      error ->
        error
    end
  end
end
