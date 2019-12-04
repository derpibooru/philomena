defmodule PhilomenaWeb.Image.Comment.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ReportController
  alias PhilomenaWeb.ReportView
  alias Philomena.Comments.Comment
  alias Philomena.Images.Image
  alias Philomena.Reports.Report
  alias Philomena.Reports

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.UserAttributionPlug
  plug PhilomenaWeb.CaptchaPlug when action in [:create]
  plug PhilomenaWeb.CanaryMapPlug, new: :show, create: :show
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true, preload: [:tags]
  plug :load_and_authorize_resource, model: Comment, id_name: "comment_id", persisted: true, preload: [:image]

  def new(conn, _params) do
    comment = conn.assigns.comment
    action = Routes.image_comment_report_path(conn, :create, comment.image, comment)
    changeset =
      %Report{reportable_type: "Comment", reportable_id: comment.id}
      |> Reports.change_report()

    conn
    |> put_view(ReportView)
    |> render("new.html", reportable: comment, changeset: changeset, action: action)
  end

  def create(conn, params) do
    comment = conn.assigns.comment
    action = Routes.image_comment_report_path(conn, :create, comment.image, comment)

    ReportController.create(conn, action, comment, "Comment", params)
  end
end