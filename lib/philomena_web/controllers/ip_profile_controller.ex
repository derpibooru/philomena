defmodule PhilomenaWeb.IpProfileController do
  use PhilomenaWeb, :controller

  alias Philomena.UserIps.UserIp
  alias Philomena.Bans.Subnet
  alias Philomena.Repo
  import Ecto.Query

  plug :authorize_ip

  def show(conn, %{"id" => ip}) do
    {:ok, ip} = EctoNetwork.INET.cast(ip)

    user_ips =
      UserIp
      |> where(ip: ^ip)
      |> order_by(desc: :updated_at)
      |> preload(:user)
      |> Repo.all()

    subnet_bans =
      Subnet
      |> where([s], fragment("? >>= ?", s.specification, ^ip))
      |> order_by(desc: :created_at)
      |> Repo.all()

    render(conn, "show.html",
      title: "#{ip}'s IP profile",
      ip: ip,
      user_ips: user_ips,
      subnet_bans: subnet_bans
    )
  end

  defp authorize_ip(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :show, :ip_address) do
      false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
      true -> conn
    end
  end
end
