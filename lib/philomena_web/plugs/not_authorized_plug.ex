defmodule PhilomenaWeb.NotAuthorizedPlug do
  alias Phoenix.Controller
  alias Plug.Conn

  def init([]), do: []

  def call(conn), do: call(conn, nil)
  def call(conn, _opts) do
    conn
    |> Controller.put_flash(:error, "You can't access that page.")
    |> Controller.redirect(external: conn.assigns.referrer)
    |> Conn.halt()
  end
end