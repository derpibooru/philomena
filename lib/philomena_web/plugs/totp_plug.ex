defmodule PhilomenaWeb.TotpPlug do
  @moduledoc """
  This plug ensures that a user session has a valid TOTP.

  ## Example

      plug PhilomenaWeb.TotpPlug
  """

  use PhilomenaWeb, :verified_routes

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    case conn.assigns.current_user do
      nil -> conn
      user -> maybe_require_totp_phase(user, conn)
    end
  end

  defp maybe_require_totp_phase(%{otp_required_for_login: nil}, conn), do: conn
  defp maybe_require_totp_phase(%{otp_required_for_login: false}, conn), do: conn

  defp maybe_require_totp_phase(_user, conn) do
    if conn.assigns.totp_valid? do
      conn
    else
      conn
      |> Phoenix.Controller.redirect(to: ~p"/sessions/totp/new")
      |> Plug.Conn.halt()
    end
  end
end
