defmodule PhilomenaWeb.Admin.ApprovalController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized

  def index(conn, _params) do
    images =
      Image
      |> where(approved: false)
      |> order_by(asc: :id)
      |> preload([:user, :sources, tags: [:aliases, :aliased_tag]])
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html", title: "Admin - Approval Queue", images: images)
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :approve, %Image{}) do
      true -> conn
      false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
