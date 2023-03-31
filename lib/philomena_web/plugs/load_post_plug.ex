defmodule PhilomenaWeb.LoadPostPlug do
  alias Philomena.Posts.Post
  alias Philomena.Repo

  import Plug.Conn, only: [assign: 3]
  import Canada.Can, only: [can?: 3]
  import Ecto.Query

  def init(opts),
    do: opts

  def call(%{assigns: %{topic: topic}} = conn, opts) do
    param = Keyword.get(opts, :param, "post_id")
    show_hidden = Keyword.get(opts, :show_hidden, false)

    Post
    |> where(topic_id: ^topic.id, id: ^to_string(conn.params[param]))
    |> preload(topic: :forum, user: [awards: :badge, game_profiles: :team])
    |> Repo.one()
    |> maybe_hide_post(conn, show_hidden)
  end

  defp maybe_hide_post(nil, conn, _show_hidden),
    do: PhilomenaWeb.NotFoundPlug.call(conn)

  defp maybe_hide_post(%{hidden_from_users: false} = post, conn, _show_hidden),
    do: assign(conn, :post, post)

  defp maybe_hide_post(post, %{assigns: %{current_user: user}} = conn, show_hidden) do
    case show_hidden or can?(user, :show, post) do
      true -> assign(conn, :post, post)
      false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
