defmodule PhilomenaWeb.DuplicateReportController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    with {:ok, duplicate_reports, changeset} <-
           DuplicateReports.list_duplicate_reports(
             conn.assigns.actor,
             query_param(params, "dq"),
             conn.assigns.scrivener
           ) do
      render(conn, "index.html",
        title: "Duplicate Reports",
        duplicate_reports: duplicate_reports,
        changeset: changeset,
        layout_class: "layout--wide"
      )
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, duplicate_report} <-
           DuplicateReports.show_duplicate_report(conn.assigns.actor, id) do
      render(conn, "show.html",
        title: "Showing Duplicate Report",
        duplicate_report: duplicate_report,
        layout_class: "layout--wide"
      )
    end
  end

  def create(conn, %{"duplicate_report" => attrs}) when is_map(attrs) do
    case DuplicateReports.create_duplicate_report(
           conn.assigns.actor,
           attrs["image_id"],
           attrs["duplicate_of_image_id"],
           attrs
         ) do
      {:ok, duplicate_report} ->
        conn
        |> put_flash(:info, "Duplicate report created successfully.")
        |> redirect(to: ~p"/images/#{duplicate_report.image_id}")

      {:error, %Ecto.Changeset{data: %{image: source}}} when not is_nil(source) ->
        conn
        |> put_flash(:error, "Failed to submit duplicate report")
        |> redirect(to: ~p"/images/#{source}")

      error ->
        error
    end
  end

  def create(_conn, _params), do: {:error, :not_found}
end
