defmodule PhilomenaWeb.ForumListPlug do
  alias Plug.Conn

  alias Philomena.Forums

  def init(opts), do: opts

  def call(conn, _opts) do
    forums = Forums.list_forums(conn.assigns.actor)

    Conn.assign(conn, :forums, forums)
  end
end
