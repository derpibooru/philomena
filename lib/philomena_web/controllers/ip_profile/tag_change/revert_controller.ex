defmodule PhilomenaWeb.IpProfile.TagChange.RevertController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"ip_profile_id" => ip}) do
    with {:ok, _target} <- TagChanges.create_ip_tag_change_revert(conn.assigns.actor, ip) do
      conn
      |> put_flash(:info, "Reversion of tag changes enqueued.")
      |> redirect(external: conn.assigns.referrer)
    end
  end
end
