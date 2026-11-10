defmodule PhilomenaWeb.ApiTokenPlug do
  alias Philomena.Users
  alias Plug.Conn

  def init([]), do: []

  def call(conn, _opts) do
    Conn.assign(conn, :current_user, find_user(conn.params["key"]))
  end

  defp find_user(key) when is_binary(key), do: Users.get_user_by_authentication_token(key)
  defp find_user(_key), do: nil
end
