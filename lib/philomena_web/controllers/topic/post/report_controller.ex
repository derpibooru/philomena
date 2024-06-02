defmodule PhilomenaWeb.Topic.Post.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ReportController
  alias PhilomenaWeb.ReportView
  alias Philomena.Forums.Forum
  alias Philomena.Reports.Report
  alias Philomena.Reports

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.UserAttributionPlug
  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]

  plug PhilomenaWeb.CanaryMapPlug, new: :show, create: :show

  plug :load_and_authorize_resource,
    model: Forum,
    id_name: "forum_id",
    id_field: "short_name",
    persisted: true

  plug PhilomenaWeb.LoadTopicPlug
  plug PhilomenaWeb.LoadPostPlug

  def new(conn, _params) do
    topic = conn.assigns.topic
    post = conn.assigns.post
    action = ~p"/forums/#{topic.forum}/topics/#{topic}/posts/#{post}/reports"

    changeset =
      %Report{reportable_type: "Post", reportable_id: post.id}
      |> Reports.change_report()

    conn
    |> put_view(ReportView)
    |> render("new.html", reportable: post, changeset: changeset, action: action)
  end

  def create(conn, params) do
    topic = conn.assigns.topic
    post = conn.assigns.post
    action = ~p"/forums/#{topic.forum}/topics/#{topic}/posts/#{post}/reports"

    ReportController.create(conn, action, post, "Post", params)
  end
end
