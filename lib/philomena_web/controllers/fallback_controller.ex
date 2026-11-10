defmodule PhilomenaWeb.FallbackController do
  @moduledoc """
  Translates global context error shapes into the exact HTTP responses
  the web layer expects.

  Used with Phoenix `action_fallback` (which applies to HTML controllers too):
  when a controller action returns a bare `{:error, :unauthorized}`,
  `{:error, :not_found}`, `{:error, :ban}`, or `{:error, :forced_filter}` instead
  of a `Plug.Conn`, Phoenix invokes this controller to finish the response.

  Any action whose failure path is bespoke - a redirect to a specific
  resource, a different flash, an action-specific status - keeps a visible
  `case`/`with else` clause in the controller instead of routing through here.
  """

  use Phoenix.Controller, formats: [json: "View", html: "View"]

  @spec call(
          Plug.Conn.t(),
          {:error, :unauthorized | :not_found | :ban | :forced_filter}
        ) ::
          Plug.Conn.t()
  def call(conn, {:error, :unauthorized}), do: PhilomenaWeb.NotAuthorizedPlug.call(conn)
  def call(conn, {:error, :not_found}), do: PhilomenaWeb.NotFoundPlug.call(conn)
  def call(conn, {:error, :ban}), do: PhilomenaWeb.FilterBannedUsersPlug.ban_response(conn)

  def call(conn, {:error, :forced_filter}) do
    conn
    |> put_flash(:error, "You have been blocked from performing this action on this image.")
    |> redirect(external: conn.assigns.referrer)
  end
end
