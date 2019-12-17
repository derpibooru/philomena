defmodule PhilomenaWeb.Profile.AliasController do
  use PhilomenaWeb, :controller

  alias Philomena.UserFingerprints.UserFingerprint
  alias Philomena.UserIps.UserIp
  alias Philomena.Users.User
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show_details
  plug :load_and_authorize_resource, model: User, id_field: "slug", id_name: "profile_id", persisted: true

  def index(conn, _params) do
    user = conn.assigns.user

    # N.B.: subquery runs faster and is easier to read
    # than the equivalent join, but Ecto doesn't support
    # that for some reason (and ActiveRecord does??)

    ip_matches =
      User
      |> join(:inner, [u], _ in assoc(u, :user_ips))
      |> join(:left, [u, ui1], ui2 in UserIp, on: ui1.ip == ui2.ip)
      |> where([u, _ui1, ui2], u.id != ^user.id and ui2.user_id == ^user.id)
      |> select([u, _ui1, _ui2], u)
      |> preload(:bans)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    fp_matches =
      User
      |> join(:inner, [u], _ in assoc(u, :user_fingerprints))
      |> join(:left, [u, uf1], uf2 in UserFingerprint, on: uf1.fingerprint == uf2.fingerprint)
      |> where([u, _uf1, uf2], u.id != ^user.id and uf2.user_id == ^user.id)
      |> select([u, _uf1, _uf2], u)
      |> preload(:bans)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    both_matches =
      Map.take(ip_matches, Map.keys(fp_matches))

    ip_matches =
      Map.drop(ip_matches, Map.keys(both_matches))

    fp_matches =
      Map.drop(fp_matches, Map.keys(both_matches))

    both_matches = Map.values(both_matches)
    ip_matches = Map.values(ip_matches)
    fp_matches = Map.values(fp_matches)

    render(
      conn,
      "index.html",
      title: "Potential Aliases for `#{user.name}'",
      both_matches: both_matches,
      ip_matches: ip_matches,
      fp_matches: fp_matches
    )
  end
end
