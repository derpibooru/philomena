defmodule PhilomenaWeb.Plugs.FilterBannedUsers do
  @moduledoc """
  This plug redirects back if there is a ban for the current user.
  CurrentBan must also be plugged, and it must come after it.

  ## Example

      plug PhilomenaWeb.Plugs.FilterBannedUsers
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
  end

  def maybe_halt(nil, conn, _redirect_url), do: conn
  def maybe_halt(_current_ban, conn, redirect_url) do
    conn
    |> Controller.put_flash(:error, "You are currently banned.")
    |> Controller.redirect(to: redirect_url)
    |> Conn.halt()
  end
end