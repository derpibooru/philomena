defmodule PhilomenaWeb.DuplicateReport.RejectController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"duplicate_report_id" => id}) do
    case DuplicateReports.create_duplicate_report_reject(conn.assigns.actor, id) do
      {:ok, report} ->
        conn
        |> put_view(PhilomenaWeb.DuplicateReportView)
        |> render("_duplicate_reports.html",
          layout: false,
          duplicate_reports: [report]
        )

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Failed to reject report.")
        |> send_resp(:multiple_choices, "")
        |> halt()

      error ->
        error
    end
  end
end
