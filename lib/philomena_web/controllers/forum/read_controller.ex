defmodule PhilomenaWeb.Forum.ReadController do
  import Plug.Conn
  use PhilomenaWeb, :controller

  alias Philomena.Forums.Forum
  alias Philomena.Forums

  plug :load_and_authorize_resource, model: Forum, id_name: "forum_id", id_field: "short_name", persisted: true

  def create(conn, _params) do
    forum = conn.assigns.forum
    user = conn.assigns.current_user

    Forums.clear_notification(forum, user)

    send_resp(conn, :ok, "")
  end
end