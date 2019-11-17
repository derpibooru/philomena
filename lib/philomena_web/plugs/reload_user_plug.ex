defmodule PhilomenaWeb.ReloadUserPlug do
  alias Pow.Plug
  alias Philomena.Users.User
  alias Philomena.Repo

  def init(opts), do: opts

  def call(conn, _opts) do
    config = Plug.fetch_config(conn)

    case Plug.current_user(conn, config) do
      nil ->
        conn

      user ->
        reloaded_user = Repo.get!(User, user.id)

        Plug.assign_current_user(conn, reloaded_user, config)
    end
  end
end