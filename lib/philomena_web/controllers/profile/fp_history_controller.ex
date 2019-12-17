defmodule PhilomenaWeb.Profile.FpHistoryController do
  use PhilomenaWeb, :controller

  alias Philomena.UserFingerprints.UserFingerprint
  alias Philomena.Users.User
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show_details
  plug :load_and_authorize_resource, model: User, id_field: "slug", id_name: "profile_id", persisted: true

  def index(conn, _params) do
    user = conn.assigns.user

    user_fps =
      UserFingerprint
      |> where(user_id: ^user.id)
      |> preload(:user)
      |> order_by(desc: :updated_at)
      |> Repo.all()

    distinct_fps =
      user_fps
      |> Enum.map(& &1.fingerprint)
      |> Enum.uniq()

    other_users =
      UserFingerprint
      |> where([u], u.fingerprint in ^distinct_fps)
      |> preload(:user)
      |> order_by(desc: :updated_at)
      |> Repo.all()
      |> Enum.group_by(& &1.fingerprint)

    render(conn, "index.html", title: "FP History for `#{user.name}'", user_fps: user_fps, other_users: other_users)
  end
end
