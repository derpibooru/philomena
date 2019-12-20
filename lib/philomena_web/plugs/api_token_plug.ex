defmodule PhilomenaWeb.ApiTokenPlug do

  alias Philomena.Users.User
  alias Philomena.Repo
  alias Pow.Plug
  import Ecto.Query

  def init([]), do: []

  def call(conn, _opts) do
    conn
    |> maybe_find_user(conn.params["key"])
    |> maybe_assign_user()
  end

  defp maybe_find_user(conn, nil), do: {conn, nil}
  defp maybe_find_user(conn, key) do
    user =
      User
      |> where(authentication_token: ^key)
      |> Repo.one()

    {conn, user}
  end

  defp maybe_assign_user({conn, nil}), do: conn
  defp maybe_assign_user({conn, user}) do
    config = Plug.fetch_config(conn)

    Plug.assign_current_user(conn, user, config)
  end
end
