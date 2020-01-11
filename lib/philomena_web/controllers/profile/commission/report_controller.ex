defmodule PhilomenaWeb.Profile.Commission.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ReportController
  alias PhilomenaWeb.ReportView
  alias Philomena.Users.User
  alias Philomena.Reports.Report
  alias Philomena.Reports

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.UserAttributionPlug
  plug PhilomenaWeb.CaptchaPlug when action in [:create]
  plug PhilomenaWeb.CanaryMapPlug, new: :show, create: :show

  plug :load_resource,
    model: User,
    id_name: "profile_id",
    id_field: "slug",
    preload: [
      :verified_links,
      commission: [sheet_image: :tags, user: [awards: :badge], items: [example_image: :tags]]
    ],
    persisted: true

  plug :ensure_commission

  def new(conn, _params) do
    user = conn.assigns.user
    commission = conn.assigns.user.commission
    action = Routes.profile_commission_report_path(conn, :create, user)

    changeset =
      %Report{reportable_type: "Commission", reportable_id: commission.id}
      |> Reports.change_report()

    conn
    |> put_view(ReportView)
    |> render("new.html",
      title: "Reporting Commission",
      reportable: commission,
      changeset: changeset,
      action: action
    )
  end

  def create(conn, params) do
    user = conn.assigns.user
    commission = conn.assigns.user.commission
    action = Routes.profile_commission_report_path(conn, :create, user)

    ReportController.create(conn, action, commission, "Commission", params)
  end

  defp ensure_commission(conn, _opts) do
    case is_nil(conn.assigns.user.commission) do
      true -> PhilomenaWeb.NotFoundPlug.call(conn)
      false -> conn
    end
  end
end
