defmodule PhilomenaWeb.Admin.Report.ClaimController do
  use PhilomenaWeb, :controller

  alias Philomena.Reports

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"report_id" => report_id}) do
    case Reports.create_report_claim(conn.assigns.actor, report_id) do
      {:ok, _report} ->
        conn
        |> put_flash(:info, "Successfully marked report as in progress")
        |> redirect(to: ~p"/admin/reports")

      {:error, %Ecto.Changeset{data: report}} ->
        conn
        |> put_flash(:error, "Couldn't claim that report!")
        |> redirect(to: ~p"/admin/reports/#{report}")

      error ->
        error
    end
  end

  def delete(conn, %{"report_id" => report_id}) do
    case Reports.delete_report_claim(conn.assigns.actor, report_id) do
      {:ok, report} ->
        conn
        |> put_flash(:info, "Successfully released report.")
        |> redirect(to: ~p"/admin/reports/#{report}")

      {:error, %Ecto.Changeset{data: report}} ->
        conn
        |> put_flash(:error, "Report was not claimed!")
        |> redirect(to: ~p"/admin/reports/#{report}")

      error ->
        error
    end
  end
end
