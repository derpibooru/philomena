defmodule PhilomenaWeb.RequireUserPlug do
  import Phoenix.Controller
  import Plug.Conn

  # No options
  def init([]), do: false

  # Redirect if not logged in
  def call(conn, _opts) do
    user = conn.assigns.current_user

    if user do
      conn
    else
      conn
      |> put_flash(:error, "You must be signed in to see this page.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
