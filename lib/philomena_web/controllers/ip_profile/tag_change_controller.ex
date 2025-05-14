defmodule PhilomenaWeb.IpProfile.TagChangeController do
  use PhilomenaWeb, :controller

  alias PhilomenaQuery.IpMask
  alias Philomena.TagChanges

  plug :verify_authorized

  def index(conn, %{"ip_profile_id" => ip} = params) do
    {:ok, ip} = EctoNetwork.INET.cast(ip)
    range = IpMask.parse_mask(ip, params)

    render(conn, "index.html",
      title: "Tag Changes for IP `#{ip}'",
      ip: range,
      tag_changes:
        TagChanges.load(
          %{
            ip: range,
            added: params["added"]
          },
          conn.assigns.scrivener
        )
    )
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :show, :ip_address) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
