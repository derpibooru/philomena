defmodule PhilomenaWeb.NotFoundPlug do
  alias Phoenix.Controller
  alias Plug.Conn

  def init([]), do: []

  def call(conn), do: call(conn, nil)

  def call(conn, _opts) do
    case conn.assigns.ajax? do
      true ->
        conn
        |> Conn.resp(:not_found, "Couldn't find what you were looking for!")
        |> Conn.halt()

      false ->
        conn
        |> Controller.fetch_flash()
        |> Controller.put_flash(:error, "Couldn't find what you were looking for!")
        |> Controller.redirect(to: "/")
        |> Conn.halt()
    end
  end
end
