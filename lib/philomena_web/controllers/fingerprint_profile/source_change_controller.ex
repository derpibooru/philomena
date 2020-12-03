defmodule PhilomenaWeb.FingerprintProfile.SourceChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.SourceChanges.SourceChange
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized

  def index(conn, %{"fingerprint_profile_id" => fingerprint}) do
    source_changes =
      SourceChange
      |> where(fingerprint: ^fingerprint)
      |> order_by(desc: :id)
      |> preload([:user, image: [:user, tags: :aliases]])
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Source Changes for Fingerprint `#{fingerprint}'",
      fingerprint: fingerprint,
      source_changes: source_changes
    )
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :show, :ip_address) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
