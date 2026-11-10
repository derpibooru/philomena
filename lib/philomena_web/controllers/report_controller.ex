defmodule PhilomenaWeb.ReportController do
  use PhilomenaWeb, :controller

  alias Philomena.Reports
  alias Philomena.Reports.ReportForm

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, _params) do
    with {:ok, reports} <- Reports.list_user_reports(conn.assigns.actor, conn.assigns.scrivener) do
      render(conn, "index.html", title: "My Reports", reports: reports)
    end
  end

  # Make sure that you load the resource in your controller:
  #
  # plug PhilomenaWeb.FilterBannedUsersPlug
  # plug PhilomenaWeb.UserAttributionPlug
  # plug PhilomenaWeb.CaptchaPlug
  # plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]
  # plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def create(conn, locator, action_for_target, params) do
    case Reports.create_report(conn.assigns.actor, locator, params["report"]) do
      {:ok, _report} ->
        conn
        |> put_flash(
          :info,
          "Your report has been received and will be checked by staff shortly."
        )
        |> redirect(to: redirect_path(conn.assigns.current_user))

      {:error, :too_many_reports} ->
        conn
        |> put_flash(
          :error,
          "You may not have more than #{Reports.max_open_reports()} open reports at a time. Did you read the reporting tips?"
        )
        |> redirect(to: "/")

      {:error, %ReportForm{target: target, changeset: changeset, rules: rules}} ->
        # The calling controllers are thin wrappers with no view of their own,
        # so Phoenix's default view - derived from the caller's name - does
        # not exist. Name the shared one explicitly.
        conn
        |> put_view(PhilomenaWeb.ReportView)
        |> render("new.html",
          subject: target,
          changeset: changeset,
          rules: rules,
          action: action_for_target.(target)
        )

      {:error, _reason} = error ->
        error
    end
  end

  defp redirect_path(nil), do: "/"
  defp redirect_path(_user), do: ~p"/reports"
end
