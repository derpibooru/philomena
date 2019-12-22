defmodule PhilomenaWeb.CommentLoader do
  alias Philomena.Comments.Comment
  alias Philomena.Repo
  import Ecto.Query

  # More aggressive preloading skipped due to overhead
  # from scrivener:
  #
  # |> join(:left, [c], _ in assoc(c, :image))
  # |> join(:left, [c, _i], _ in assoc(c, :user))
  # |> join(:left, [_c, _i, u], _ in assoc(u, :awards))
  # |> join(:left, [_c, _i, _u, a], _ in assoc(a, :badge))
  # |> preload([_c, i, u, a, b], [:deleted_by, image: i, user: {u, awards: {a, badge: b}}])

  def load_comments(conn, image) do
    pref = load_direction(conn.assigns.current_user)

    Comment
    |> where(image_id: ^image.id)
    |> order_by([{^pref, :created_at}])
    |> preload([:image, :deleted_by, user: [awards: :badge]])
    |> Repo.paginate(conn.assigns.comment_scrivener)
  end

  def find_page(conn, image, comment_id) do
    user = conn.assigns.current_user

    comment =
      Comment
      |> where(image_id: ^image.id)
      |> where(id: ^comment_id)
      |> Repo.one!()

    offset =
      Comment
      |> where(image_id: ^image.id)
      |> filter_direction(comment.created_at, user)
      |> Repo.aggregate(:count, :id)

    page_size = conn.assigns.comment_scrivener[:page_size]

    # Pagination starts at page 1
    div(offset, page_size) + 1
  end

  defp load_direction(%{comments_newest_first: false}), do: :asc
  defp load_direction(_user), do: :desc

  defp filter_direction(query, time, %{comments_newest_first: false}),
    do: where(query, [c], c.created_at <= ^time)

  defp filter_direction(query, time, _user),
    do: where(query, [c], c.created_at >= ^time)
end
