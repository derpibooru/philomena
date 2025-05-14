defmodule PhilomenaWeb.FingerprintProfile.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges

  plug :verify_authorized

  def index(conn, %{"fingerprint_profile_id" => fingerprint} = params) do
    render(conn, "index.html",
      title: "Tag Changes for Fingerprint `#{fingerprint}'",
      fingerprint: fingerprint,
      tag_changes:
        TagChanges.load(
          %{
            field: :fingerprint,
            value: fingerprint,
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
