defmodule PhilomenaWeb.Image.Comment.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ReportController
  alias PhilomenaWeb.ReportView
  alias Philomena.Reports

  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]

  action_fallback PhilomenaWeb.FallbackController

  def new(conn, %{"image_id" => image_id, "comment_id" => comment_id}) do
    locator = {:comment, image_id, comment_id}

    with {:ok, form} <- Reports.new_report(conn.assigns.actor, locator) do
      comment = form.target
      action = ~p"/images/#{comment.image}/comments/#{comment}/reports"

      conn
      |> put_view(ReportView)
      |> render("new.html",
        title: "Reporting Comment",
        subject: comment,
        changeset: form.changeset,
        rules: form.rules,
        action: action
      )
    end
  end

  def create(conn, %{"image_id" => image_id, "comment_id" => comment_id} = params) do
    ReportController.create(
      conn,
      {:comment, image_id, comment_id},
      fn comment -> ~p"/images/#{comment.image}/comments/#{comment}/reports" end,
      params
    )
  end
end
