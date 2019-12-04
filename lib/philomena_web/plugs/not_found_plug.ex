defmodule PhilomenaWeb.NotFoundPlug do
  alias Phoenix.Controller
  alias Plug.Conn

  def init([]), do: []

  def call(conn), do: call(conn, nil)
  def call(conn, _opts) do
    conn
    |> Controller.put_flash(:error, "Couldn't find what you were looking for!")
    |> Controller.redirect(external: conn.assigns.referrer)
    |> Conn.halt()
  end
end