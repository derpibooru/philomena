defmodule PhilomenaWeb.IpProfile.SourceChangeController do
  use PhilomenaWeb, :controller

  alias PhilomenaQuery.IpMask
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized

  def index(conn, %{"ip_profile_id" => ip} = params) do
    {:ok, ip} = EctoNetwork.INET.cast(ip)
    range = IpMask.parse_mask(ip, params)

    source_changes =
      SourceChange
      |> where(fragment("? >>= ip", ^range))
      |> added_filter(params)
      |> order_by(desc: :id)
      |> preload([:user, image: [:user, :sources, tags: :aliases]])
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Source Changes for IP `#{ip}'",
      ip: range,
      source_changes: source_changes
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
