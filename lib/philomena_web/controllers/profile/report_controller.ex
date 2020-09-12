defmodule PhilomenaWeb.Profile.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ReportController
  alias PhilomenaWeb.ReportView
  alias Philomena.Users.User
  alias Philomena.Reports.Report
  alias Philomena.Reports

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.UserAttributionPlug
  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]
  plug PhilomenaWeb.CanaryMapPlug, new: :show, create: :show

  plug :load_and_authorize_resource,
    model: User,
    id_name: "profile_id",
    id_field: "slug",
    persisted: true

  def new(conn, _params) do
    user = conn.assigns.user
    action = Routes.profile_report_path(conn, :create, user)

    changeset =
      %Report{reportable_type: "User", reportable_id: user.id}
      |> Reports.change_report()

    conn
    |> put_view(ReportView)
    |> render("new.html",
      title: "Reporting User",
      reportable: user,
      changeset: changeset,
      action: action
    )
  end

  def create(conn, params) do
    user = conn.assigns.user
    action = Routes.profile_report_path(conn, :create, user)

    ReportController.create(conn, action, user, "User", params)
  end
end
