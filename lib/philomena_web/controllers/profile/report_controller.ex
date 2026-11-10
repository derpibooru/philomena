defmodule PhilomenaWeb.Profile.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ReportController
  alias PhilomenaWeb.ReportView
  alias Philomena.Reports

  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]

  action_fallback PhilomenaWeb.FallbackController

  def new(conn, %{"profile_id" => slug}) do
    with {:ok, form} <- Reports.new_report(conn.assigns.actor, {:user, slug}) do
      user = form.target
      action = ~p"/profiles/#{user}/reports"

      conn
      |> put_view(ReportView)
      |> render("new.html",
        title: "Reporting User",
        subject: user,
        changeset: form.changeset,
        rules: form.rules,
        action: action
      )
    end
  end

  def create(conn, %{"profile_id" => slug} = params) do
    ReportController.create(
      conn,
      {:user, slug},
      fn user -> ~p"/profiles/#{user}/reports" end,
      params
    )
  end
end
