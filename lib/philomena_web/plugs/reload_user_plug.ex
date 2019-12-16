defmodule PhilomenaWeb.ReloadUserPlug do
  alias Pow.Plug
  alias Philomena.Users

  def init(opts), do: opts

  def call(conn, _opts) do
    config = Plug.fetch_config(conn)

    case Plug.current_user(conn, config) do
      nil ->
        conn

      user ->
        reloaded_user = Users.get_by(id: user.id)

        Plug.assign_current_user(conn, reloaded_user, config)
    end
  end
end
