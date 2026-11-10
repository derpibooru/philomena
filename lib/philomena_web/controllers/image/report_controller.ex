defmodule PhilomenaWeb.Image.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ReportController
  alias PhilomenaWeb.ReportView
  alias Philomena.Reports

  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]

  action_fallback PhilomenaWeb.FallbackController

  def new(conn, %{"image_id" => image_id}) do
    with {:ok, form} <- Reports.new_report(conn.assigns.actor, {:image, image_id}) do
      image = form.target
      action = ~p"/images/#{image}/reports"

      conn
      |> put_view(ReportView)
      |> render("new.html",
        title: "Reporting Image",
        subject: image,
        changeset: form.changeset,
        rules: form.rules,
        action: action
      )
    end
  end

  def create(conn, %{"image_id" => image_id} = params) do
    ReportController.create(
      conn,
      {:image, image_id},
      fn image -> ~p"/images/#{image}/reports" end,
      params
    )
  end
end
