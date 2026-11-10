defmodule PhilomenaWeb.ModerationLogController do
  use PhilomenaWeb, :controller

  alias Philomena.ModerationLogs

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, _params) do
    with {:ok, moderation_logs} <-
           ModerationLogs.list_moderation_logs(conn.assigns.actor, conn.assigns.scrivener) do
      render(conn, "index.html", title: "Moderation Logs", moderation_logs: moderation_logs)
    end
  end
end
