defmodule PhilomenaWeb.NotAuthorizedPlug do
  alias Phoenix.Controller
  alias Plug.Conn

  def init([]), do: []

  def call(conn), do: call(conn, nil)

  def call(conn, _opts) do
    if conn.assigns.ajax? do
      conn
      |> Conn.resp(:forbidden, "You can't access that page.")
      |> Conn.halt()
    else
      conn
      |> Controller.fetch_flash()
      |> Controller.put_flash(:error, "You can't access that page.")
      |> Controller.redirect(to: "/")
      |> Conn.halt()
    end
  end
end
