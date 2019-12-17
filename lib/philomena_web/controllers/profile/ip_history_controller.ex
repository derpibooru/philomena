defmodule PhilomenaWeb.Profile.IpHistoryController do
  use PhilomenaWeb, :controller

  alias Philomena.UserIps.UserIp
  alias Philomena.Users.User
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show_details
  plug :load_and_authorize_resource, model: User, id_field: "slug", id_name: "profile_id", persisted: true

  def index(conn, _params) do
    user = conn.assigns.user

    user_ips =
      UserIp
      |> where(user_id: ^user.id)
      |> preload(:user)
      |> order_by(desc: :updated_at)
      |> Repo.all()

    distinct_ips =
      user_ips
      |> Enum.map(& &1.ip)
      |> Enum.uniq()

    other_users =
      UserIp
      |> where([u], u.ip in ^distinct_ips)
      |> preload(:user)
      |> order_by(desc: :updated_at)
      |> Repo.all()
      |> Enum.group_by(& &1.ip)

    render(conn, "index.html", title: "IP History for `#{user.name}'", user_ips: user_ips, other_users: other_users)
  end
end
