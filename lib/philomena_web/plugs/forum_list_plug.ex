defmodule PhilomenaWeb.ForumListPlug do
  alias Plug.Conn

  alias Philomena.Forums.Forum
  alias Philomena.Repo
  alias Canada.Can
  import Ecto.Query

  def init(opts), do: opts

  def call(conn, _opts) do
    forums = lookup_visible_forums(conn.assigns.current_user)

    conn
    |> Conn.assign(:forums, forums)
  end

  # fixme: add caching!
  defp lookup_visible_forums(user) do
    Forum
    |> order_by(asc: :name)
    |> Repo.all()
    |> Enum.filter(&Can.can?(user, :show, &1))
  end
end
