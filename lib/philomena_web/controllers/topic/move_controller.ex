defmodule PhilomenaWeb.Topic.MoveController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Topics.Topic
  alias Philomena.Topics
  alias Philomena.Repo
  import Ecto.Query

  plug :load_topic
  plug PhilomenaWeb.CanaryMapPlug, create: :stick, delete: :stick
  plug :authorize_resource, model: Topic, id_name: "topic_id", persisted: true

  # intentionally blank
  # todo: moving
  def create(conn, _opts) do
  end

  defp load_topic(conn, _opts) do
    topic = Topic
    |> where(forum_id: ^conn.params["forum_id"], slug: ^conn.params["topic_id"])
    |> Repo.one()

    Plug.Conn.assign(conn, :topic, topic)
  end
end
