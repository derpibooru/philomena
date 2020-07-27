defmodule PhilomenaWeb.NameLengthLimiterPlug do
	alias Phoenix.Controller
	alias Plug.Conn

	def init([]), do: []

	def call(conn), do: call(conn, nil)

	def call(conn, _opts) do
    name = conn.params["user"]["name"]

	  conn
	  |> check_length(name)
  end

  defp check_length(conn, name) do
    if too_long?(name) do
      conn
      |> Controller.fetch_flash()
      |> Controller.put_flash(:error, "Names must be 80 characters or shorter.")
      |> Controller.redirect(external: conn.assigns.referrer)
      |> Conn.halt()
    else
      conn
    end
  end

	defp too_long?(name) do
		String.length(name) > 80
	end

end
