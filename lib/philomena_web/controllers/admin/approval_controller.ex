defmodule PhilomenaWeb.Admin.ApprovalController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, _params) do
    with {:ok, images} <-
           Images.list_approval_queue(conn.assigns.actor, conn.assigns.scrivener) do
      render(conn, "index.html", title: "Admin - Approval Queue", images: images)
    end
  end
end
