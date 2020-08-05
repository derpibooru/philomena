defmodule PhilomenaWeb.DevOnlyPlug do
  alias Phoenix.Controller
  alias Plug.Conn

  def init([]), do: []

  def call(conn), do: call(conn, nil)

  def call(conn, _opts) do
    case Application.get_env(:philomena, :app_env) do
      "dev" ->
        conn
      _ ->
        conn
          |> Controller.redirect(to: "/")
          |> Conn.halt()
    end
  end
end
