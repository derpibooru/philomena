defmodule PhilomenaWeb.FilterBannedUsersPlug do
  @moduledoc """
  This plug redirects back if there is a ban for the current user.
  CurrentBanPlug must also be plugged, and this must come after it.

  ## Example

      plug PhilomenaWeb.FilterBannedUsersPlug
  """
  alias Phoenix.Controller
  alias Plug.Conn

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    redirect_url = conn.assigns.referrer

    conn.assigns.current_ban
    |> maybe_halt(conn, redirect_url)
    |> maybe_halt_no_fingerprint()
  end

  defp maybe_halt(nil, conn, _redirect_url), do: conn
  defp maybe_halt(_current_ban, conn, redirect_url) do
    conn
    |> Controller.put_flash(:error, "You are currently banned.")
    |> Controller.redirect(external: redirect_url)
    |> Conn.halt()
  end

  defp maybe_halt_no_fingerprint(%{halted: true} = conn), do: conn
  defp maybe_halt_no_fingerprint(conn) do
    conn = Conn.fetch_cookies(conn)

    case conn.cookies["_ses"] do
      nil ->
        PhilomenaWeb.NotAuthorizedPlug.call(conn)

      _other ->
        conn
    end
  end
end
