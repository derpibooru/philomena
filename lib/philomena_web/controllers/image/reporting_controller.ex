defmodule PhilomenaWeb.Image.ReportingController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports

  action_fallback PhilomenaWeb.FallbackController

  def show(conn, params) do
    with {:ok, {image, dupe_reports, changeset}} <-
           DuplicateReports.new_duplicate_report(conn.assigns.actor, params["image_id"]) do
      render(conn, "show.html",
        layout: false,
        image: image,
        dupe_reports: dupe_reports,
        changeset: changeset
      )
    end
  end
end
