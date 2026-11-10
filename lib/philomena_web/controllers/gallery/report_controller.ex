defmodule PhilomenaWeb.Gallery.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ReportController
  alias PhilomenaWeb.ReportView
  alias Philomena.Reports

  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]

  action_fallback PhilomenaWeb.FallbackController

  def new(conn, %{"gallery_id" => gallery_id}) do
    with {:ok, form} <- Reports.new_report(conn.assigns.actor, {:gallery, gallery_id}) do
      gallery = form.target
      action = ~p"/galleries/#{gallery}/reports"

      conn
      |> put_view(ReportView)
      |> render("new.html",
        title: "Reporting Gallery",
        subject: gallery,
        changeset: form.changeset,
        rules: form.rules,
        action: action
      )
    end
  end

  def create(conn, %{"gallery_id" => gallery_id} = params) do
    ReportController.create(
      conn,
      {:gallery, gallery_id},
      fn gallery -> ~p"/galleries/#{gallery}/reports" end,
      params
    )
  end
end
