defmodule PhilomenaWeb.Image.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ReportController
  alias PhilomenaWeb.ReportView
  alias Philomena.Images.Image
  alias Philomena.Reports.Report
  alias Philomena.Reports

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.UserAttributionPlug
  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]
  plug PhilomenaWeb.CanaryMapPlug, new: :show, create: :show

  plug :load_and_authorize_resource,
    model: Image,
    id_name: "image_id",
    persisted: true,
    preload: [:sources, tags: :aliases]

  def new(conn, _params) do
    image = conn.assigns.image
    action = ~p"/images/#{image}/reports"

    changeset =
      %Report{reportable_type: "Image", reportable_id: image.id}
      |> Reports.change_report()

    conn
    |> put_view(ReportView)
    |> render("new.html",
      title: "Reporting Image",
      reportable: image,
      changeset: changeset,
      action: action
    )
  end

  def create(conn, params) do
    image = conn.assigns.image
    action = ~p"/images/#{image}/reports"

    ReportController.create(conn, action, "Image", image, params)
  end
end
