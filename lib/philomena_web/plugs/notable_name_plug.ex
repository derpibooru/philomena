defmodule PhilomenaWeb.NotableNamePlug do
	alias Philomena.Notable
	alias Phoenix.Controller
	alias Plug.Conn

	def init([]), do: []

	def call(conn), do: call(conn, nil)

	def call(conn, _opts) do
    name = conn.params["user"]["name"]

	  conn
	  |> check_notable(name)
  end

  defp mod?(%{role: role}) when role in ["moderator", "admin"], do: true
  defp mod?(_user), do: false

  defp check_notable(conn, user_name) do
	  if Notable.notable_name?(user_name) do
	    conn
	    |> allow_mods
	  else
	    conn
    end
  end

  defp allow_mods(conn) do
    unless mod?(conn.assigns.current_user) do
      import Phoenix.HTML.Link, only: [link: 2]

      conn
        |> Controller.fetch_flash()
        |> Controller.put_flash(:error, ["That username is reserved for a notable fandom artist. Please choose another, and if you are the artist in question, ", link("contact the moderators", to: "/forums/meta"), " for verification."])
        |> Controller.redirect(external: conn.assigns.referrer)
        |> Conn.halt()
    else
      conn
    end
  end


end
