defmodule PhilomenaWeb.FingerprintProfileController do
  use PhilomenaWeb, :controller

  alias Philomena.UserFingerprints.UserFingerprint
  alias Philomena.Bans.Fingerprint
  alias Philomena.Repo
  import Ecto.Query

  plug :authorize_ip

  def show(conn, %{"id" => fingerprint}) do
    user_fps =
      UserFingerprint
      |> where(fingerprint: ^fingerprint)
      |> order_by(desc: :updated_at)
      |> preload(:user)
      |> Repo.all()

    fp_bans =
      Fingerprint
      |> where(fingerprint: ^fingerprint)
      |> order_by(desc: :created_at)
      |> Repo.all()

    render(conn, "show.html",
      title: "#{fingerprint}'s fingerprint profile",
      fingerprint: fingerprint,
      user_fps: user_fps,
      fingerprint_bans: fp_bans
    )
  end

  defp authorize_ip(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :show, :ip_address) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
