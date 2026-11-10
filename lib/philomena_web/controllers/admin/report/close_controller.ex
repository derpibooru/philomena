defmodule PhilomenaWeb.Admin.Report.CloseController do
  use PhilomenaWeb, :controller

  alias Philomena.Reports

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"report_id" => report_id}) do
    case Reports.create_report_close(conn.assigns.actor, report_id) do
      {:ok, _report} ->
        conn
        |> put_flash(:info, "Successfully closed report")
        |> redirect(to: ~p"/admin/reports")

      {:error, %Ecto.Changeset{data: report}} ->
        conn
        |> put_flash(:error, "Failed to close report")
        |> redirect(to: ~p"/admin/reports/#{report}")

      error ->
        error
    end
  end
end
