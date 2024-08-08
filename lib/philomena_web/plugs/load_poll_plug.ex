defmodule PhilomenaWeb.LoadPollPlug do
  alias Philomena.Polls.Poll
  alias Philomena.Repo

  import Ecto.Query

  def init(opts), do: opts

  def call(%{assigns: %{topic: topic}} = conn, _opts) do
    Poll
    |> where(topic_id: ^topic.id)
    |> Repo.one()
    |> case do
      nil ->
        PhilomenaWeb.NotFoundPlug.call(conn)

      poll ->
        Plug.Conn.assign(conn, :poll, poll)
    end
  end
end
