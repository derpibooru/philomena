defmodule PhilomenaWeb.Profile.TagChange.RevertController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"profile_id" => user_id}) do
    with {:ok, _target} <- TagChanges.create_user_tag_change_revert(conn.assigns.actor, user_id) do
      conn
      |> put_flash(:info, "Reversion of tag changes enqueued.")
      |> redirect(external: conn.assigns.referrer)
    end
  end
end
