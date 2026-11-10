defmodule PhilomenaWeb.Tag.DetailController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    with {:ok, detail} <- Tags.list_tag_details(conn.assigns.actor, params["tag_id"]) do
      render(
        conn,
        "index.html",
        title: "Tag Usage for Tag `#{detail.tag.name}'",
        tag: detail.tag,
        filters_spoilering: detail.filters_spoilering,
        filters_hiding: detail.filters_hiding,
        users_watching: detail.users_watching
      )
    end
  end
end
