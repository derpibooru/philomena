defmodule PhilomenaWeb.Topic.ReadController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Forums.Forum
  alias Philomena.Topics

  plug PhilomenaWeb.CanaryMapPlug, create: :show

  plug :load_and_authorize_resource,
    model: Forum,
    id_name: "forum_id",
    id_field: "short_name",
    persisted: true

  plug PhilomenaWeb.LoadTopicPlug, show_hidden: true

  def create(conn, _params) do
    user = conn.assigns.current_user

    Topics.clear_notification(conn.assigns.topic, user)

    send_resp(conn, :ok, "")
  end
end
