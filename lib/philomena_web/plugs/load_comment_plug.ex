defmodule PhilomenaWeb.LoadCommentPlug do
  alias Philomena.Comments.Comment
  alias Philomena.Repo

  import Plug.Conn, only: [assign: 3]
  import Canada.Can, only: [can?: 3]
  import Ecto.Query

  def init(opts),
    do: opts

  def call(%{assigns: %{image: image}} = conn, opts) do
    param = Keyword.get(opts, :param, "comment_id")
    show_hidden = Keyword.get(opts, :show_hidden, false)

    Comment
    |> where(image_id: ^image.id, id: ^to_string(conn.params[param]))
    |> preload([:image, :deleted_by, user: [awards: :badge]])
    |> Repo.one()
    |> maybe_hide_comment(conn, show_hidden)
  end

  defp maybe_hide_comment(nil, conn, _show_hidden),
    do: PhilomenaWeb.NotFoundPlug.call(conn)

  defp maybe_hide_comment(%{hidden_from_users: false} = comment, conn, _show_hidden),
    do: assign(conn, :comment, comment)

  defp maybe_hide_comment(comment, %{assigns: %{current_user: user}} = conn, show_hidden) do
    case show_hidden or can?(user, :show, comment) do
      true -> assign(conn, :comment, comment)
      false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
