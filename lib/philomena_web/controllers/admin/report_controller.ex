defmodule PhilomenaWeb.Admin.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.Reports

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    case Reports.list_reports(
           conn.assigns.actor,
           query_param(params, "rq"),
           conn.assigns.pagination
         ) do
      {:ok, page, query_changeset} ->
        render(conn, "index.html",
          title: "Admin - Reports",
          layout_class: "layout--wide",
          reports: page.reports,
          my_reports: page.my_reports,
          system_reports: page.system_reports,
          changeset: query_changeset
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "index.html",
          title: "Admin - Reports",
          layout_class: "layout--wide",
          reports: nil,
          my_reports: [],
          system_reports: [],
          changeset: changeset
        )

      error ->
        error
    end
  end

  def show(conn, %{"id" => report_id}) do
    with {:ok, report} <- Reports.show_report(conn.assigns.actor, report_id) do
      body = MarkdownRenderer.render_one(%{body: report.reason}, conn)

      render(conn, "show.html",
        title: "Showing Report",
        report: report,
        body: body,
        mod_notes: mod_notes(conn, report)
      )
    end
  end

  defp mod_notes(conn, report) do
    renderer = &MarkdownRenderer.render_collection(&1, conn)
    Reports.mod_notes(conn.assigns.actor, report, renderer)
  end
end
