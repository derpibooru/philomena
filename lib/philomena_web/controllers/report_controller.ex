defmodule PhilomenaWeb.ReportController do
  use PhilomenaWeb, :controller

  alias Philomena.Polymorphic
  alias Philomena.Reports.Report
  alias Philomena.Reports
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, _params) do
    user = conn.assigns.current_user

    reports =
      Report
      |> where(user_id: ^user.id)
      |> order_by(desc: :created_at)
      |> Repo.paginate(conn.assigns.scrivener)

    polymorphic =
      reports
      |> Polymorphic.load_polymorphic(reportable: [reportable_id: :reportable_type])

    reports = %{reports | entries: polymorphic}

    render(conn, "index.html", title: "My Reports", reports: reports)
  end

  # Make sure that you load the resource in your controller:
  #
  # plug PhilomenaWeb.FilterBannedUsersPlug
  # plug PhilomenaWeb.UserAttributionPlug
  # plug PhilomenaWeb.CaptchaPlug
  # plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]
  # plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def create(conn, action, reportable_type, reportable, %{"report" => report_params}) do
    attribution = conn.assigns.attributes

    if too_many_reports?(conn) do
      conn
      |> put_flash(
        :error,
        "You may not have more than #{max_reports()} open reports at a time. Did you read the reporting tips?"
      )
      |> redirect(to: "/")
    else
      case Reports.create_report({reportable_type, reportable.id}, attribution, report_params) do
        {:ok, _report} ->
          conn
          |> put_flash(
            :info,
            "Your report has been received and will be checked by staff shortly."
          )
          |> redirect(to: redirect_path(conn.assigns.current_user))

        {:error, changeset} ->
          # Note that we are depending on the controller that called
          # us to have set up the view already (Phoenix does this)
          conn
          |> render("new.html", reportable: reportable, changeset: changeset, action: action)
      end
    end
  end

  defp too_many_reports?(conn) do
    user = conn.assigns.current_user

    case user do
      %{role: role} when role != "user" ->
        false

      _user ->
        too_many_reports_user?(user) or too_many_reports_ip?(conn)
    end
  end

  defp too_many_reports_user?(nil), do: false

  defp too_many_reports_user?(user) do
    reports_open =
      Report
      |> where(user_id: ^user.id)
      |> where([r], r.state in ["open", "in_progress"])
      |> Repo.aggregate(:count, :id)

    reports_open >= max_reports()
  end

  defp too_many_reports_ip?(conn) do
    attribution = conn.assigns.attributes

    reports_open =
      Report
      |> where(ip: ^attribution[:ip])
      |> where([r], r.state in ["open", "in_progress"])
      |> Repo.aggregate(:count, :id)

    reports_open >= max_reports()
  end

  defp redirect_path(nil), do: "/"
  defp redirect_path(_user), do: ~p"/reports"

  defp max_reports do
    5
  end
end
