defmodule PhilomenaWeb.Profile.Commission.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ReportController
  alias PhilomenaWeb.ReportView
  alias Philomena.Reports

  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]

  action_fallback PhilomenaWeb.FallbackController

  def new(conn, %{"profile_id" => slug}) do
    with {:ok, form} <- Reports.new_report(conn.assigns.actor, {:commission, slug}) do
      commission = form.target
      user = commission.user
      action = ~p"/profiles/#{user}/commission/reports"

      conn
      |> put_view(ReportView)
      |> render("new.html",
        title: "Reporting Commission",
        subject: commission,
        changeset: form.changeset,
        rules: form.rules,
        action: action
      )
    end
  end

  def create(conn, %{"profile_id" => slug} = params) do
    ReportController.create(
      conn,
      {:commission, slug},
      fn commission -> ~p"/profiles/#{commission.user}/commission/reports" end,
      params
    )
  end
end
