defmodule PhilomenaWeb.IpProfile.TagChangeController do
  use PhilomenaWeb, :controller

  alias PhilomenaQuery.IpMask
  alias Philomena.TagChanges.TagChange
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized

  def index(conn, %{"ip_profile_id" => ip} = params) do
    {:ok, ip} = EctoNetwork.INET.cast(ip)
    range = IpMask.parse_mask(ip, params)

    tag_changes =
      TagChange
      |> where(fragment("? >>= ip", ^range))
      |> added_filter(params)
      |> preload([:tag, :user, image: [:user, :sources, tags: :aliases]])
      |> order_by(desc: :id)
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Tag Changes for IP `#{ip}'",
      ip: range,
      tag_changes: tag_changes
    )
  end

  defp added_filter(query, %{"added" => "1"}),
    do: where(query, added: true)

  defp added_filter(query, %{"added" => "0"}),
    do: where(query, added: false)

  defp added_filter(query, _params),
    do: query

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :show, :ip_address) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
