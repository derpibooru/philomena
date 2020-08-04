defmodule PhilomenaWeb.ApiTokenPlug do
  alias Philomena.Users
  alias Plug.Conn

  def init([]), do: []

  def call(conn, _opts) do
    conn
    |> maybe_find_user(conn.params["key"])
    |> assign_user()
  end

  defp maybe_find_user(conn, nil), do: {conn, nil}

  defp maybe_find_user(conn, token) do
    user = Users.get_user_by_authentication_token(token)

    {conn, user}
  end

  defp assign_user({conn, user}) do
    Conn.assign(conn, :current_user, user)
  end
end
