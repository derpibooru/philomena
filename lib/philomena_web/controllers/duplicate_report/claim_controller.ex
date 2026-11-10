defmodule PhilomenaWeb.DuplicateReport.ClaimController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"duplicate_report_id" => id}) do
    case DuplicateReports.create_duplicate_report_claim(conn.assigns.actor, id) do
      {:ok, report} ->
        conn
        |> put_view(PhilomenaWeb.DuplicateReportView)
        |> render("_duplicate_reports.html",
          layout: false,
          duplicate_reports: [report]
        )

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Failed to claim report.")
        |> send_resp(:multiple_choices, "")
        |> halt()

      error ->
        error
    end
  end

  def delete(conn, %{"duplicate_report_id" => id}) do
    case DuplicateReports.delete_duplicate_report_claim(conn.assigns.actor, id) do
      {:ok, report} ->
        conn
        |> put_view(PhilomenaWeb.DuplicateReportView)
        |> render("_duplicate_reports.html",
          layout: false,
          duplicate_reports: [report]
        )

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Failed to release report.")
        |> send_resp(:multiple_choices, "")
        |> halt()

      error ->
        error
    end
  end
end
