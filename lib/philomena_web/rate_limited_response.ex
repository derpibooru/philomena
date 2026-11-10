defmodule PhilomenaWeb.RateLimitedResponse do
  @moduledoc """
  Renders the response for a write refused with `{:error, :rate_limited}`.

  The flash carries the controller-specific message. AJAX requests get an
  empty 300 response (ujs.ts reloads the page so the flash renders);
  everything else is redirected back to the referrer.
  """

  alias Plug.Conn
  alias Phoenix.Controller

  @spec call(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def call(conn, message) do
    conn = Controller.put_flash(conn, :error, message)

    if conn.assigns.ajax? do
      conn
      |> Conn.send_resp(:multiple_choices, "")
      |> Conn.halt()
    else
      conn
      |> Controller.redirect(external: conn.assigns.referrer)
      |> Conn.halt()
    end
  end
end
