defmodule PhilomenaWeb.Plugs.RequireUser do
  import Phoenix.Controller
  import Plug.Conn
  import Pow.Plug

  # No options
  def init([]), do: false

  # Redirect if not logged in
  def call(conn, _opts) do
    user = conn |> current_user()

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
