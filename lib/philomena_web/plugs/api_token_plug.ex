defmodule PhilomenaWeb.ApiTokenPlug do
  alias Philomena.Users
  alias Pow.Plug

  def init([]), do: []

  def call(conn, _opts) do
    conn
    |> maybe_find_user(conn.params["key"])
    |> assign_user()
  end

  defp maybe_find_user(conn, nil), do: {conn, nil}
  defp maybe_find_user(conn, key) do
    user = Users.get_by(authentication_token: key)

    {conn, user}
  end

  defp assign_user({conn, user}) do
    config = Plug.fetch_config(conn)

    Plug.assign_current_user(conn, user, config)
  end
end
