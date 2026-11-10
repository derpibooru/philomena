defmodule PhilomenaWeb.Tag.ReindexController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    with {:ok, tag} <- Tags.create_tag_reindex(conn.assigns.actor, params["tag_id"]) do
      conn
      |> put_flash(:info, "Tag reindex started.")
      |> redirect(to: ~p"/tags/#{tag}/edit")
    end
  end
end
