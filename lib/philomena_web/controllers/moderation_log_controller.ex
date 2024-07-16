defmodule PhilomenaWeb.ModerationLogController do
  use PhilomenaWeb, :controller

  alias Philomena.ModerationLogs
  alias Philomena.ModerationLogs.ModerationLog

  plug :load_and_authorize_resource,
    model: ModerationLog,
    preload: [:user]

  def index(conn, _params) do
    moderation_logs = ModerationLogs.list_moderation_logs(conn.assigns.scrivener)
    render(conn, "index.html", title: "Moderation Logs", moderation_logs: moderation_logs)
  end
end
