defmodule PhilomenaWeb.FingerprintProfile.SourceChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.SourceChanges.SourceChange
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized

  def index(conn, %{"fingerprint_profile_id" => fingerprint} = params) do
    source_changes =
      SourceChange
      |> where(fingerprint: ^fingerprint)
      |> added_filter(params)
      |> order_by(desc: :id)
      |> preload([:user, image: [:user, :sources, tags: :aliases]])
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Source Changes for Fingerprint `#{fingerprint}'",
      fingerprint: fingerprint,
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
