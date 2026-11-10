defmodule PhilomenaWeb.Conversation.ReportController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ReportController
  alias PhilomenaWeb.ReportView
  alias Philomena.Reports

  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]

  action_fallback PhilomenaWeb.FallbackController

  def new(conn, %{"conversation_id" => conversation_id}) do
    with {:ok, form} <-
           Reports.new_report(conn.assigns.actor, {:conversation, conversation_id}) do
      conversation = form.target
      action = ~p"/conversations/#{conversation}/reports"

      conn
      |> put_view(ReportView)
      |> render("new.html",
        title: "Reporting Conversation",
        subject: conversation,
        changeset: form.changeset,
        rules: form.rules,
        action: action
      )
    end
  end

  def create(conn, %{"conversation_id" => conversation_id} = params) do
    ReportController.create(
      conn,
      {:conversation, conversation_id},
      fn conversation -> ~p"/conversations/#{conversation}/reports" end,
      params
    )
  end
end
