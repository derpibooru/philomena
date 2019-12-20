defmodule PhilomenaWeb.LoadPollPlug do
  alias Philomena.Polls.Poll
  alias Philomena.Repo

  import Plug.Conn, only: [assign: 3]
  import Canada.Can, only: [can?: 3]
  import Ecto.Query

  def init(opts),
    do: opts

  def call(%{assigns: %{topic: topic}} = conn, opts) do
    show_hidden = Keyword.get(opts, :show_hidden, false)

    Poll
    |> where(topic_id: ^topic.id)
    |> Repo.one()
    |> maybe_hide_poll(conn, show_hidden)
  end

  defp maybe_hide_poll(nil, conn, _show_hidden),
    do: PhilomenaWeb.NotFoundPlug.call(conn)

  defp maybe_hide_poll(%{hidden_from_users: false} = poll, conn, _show_hidden),
    do: assign(conn, :poll, poll)

  defp maybe_hide_poll(poll, %{assigns: %{current_user: user}} = conn, show_hidden) do
    case show_hidden or can?(user, :show, poll) do
      true  -> assign(conn, :poll, poll)
      false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
