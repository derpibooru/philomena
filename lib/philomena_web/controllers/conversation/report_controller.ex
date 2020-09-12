defmodule PhilomenaWeb.Conversation.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ReportController
  alias PhilomenaWeb.ReportView
  alias Philomena.Conversations.Conversation
  alias Philomena.Reports.Report
  alias Philomena.Reports

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.UserAttributionPlug
  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]
  plug PhilomenaWeb.CanaryMapPlug, new: :show, create: :show

  plug :load_and_authorize_resource,
    model: Conversation,
    id_name: "conversation_id",
    id_field: "slug",
    persisted: true,
    preload: [:from, :to]

  def new(conn, _params) do
    conversation = conn.assigns.conversation
    action = Routes.conversation_report_path(conn, :create, conversation)

    changeset =
      %Report{reportable_type: "Conversation", reportable_id: conversation.id}
      |> Reports.change_report()

    conn
    |> put_view(ReportView)
    |> render("new.html",
      title: "Reporting Conversation",
      reportable: conversation,
      changeset: changeset,
      action: action
    )
  end

  def create(conn, params) do
    conversation = conn.assigns.conversation
    action = Routes.conversation_report_path(conn, :create, conversation)

    ReportController.create(conn, action, conversation, "Conversation", params)
  end
end
