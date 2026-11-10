defmodule PhilomenaWeb.Topic.ReadController do
  use PhilomenaWeb, :controller

  alias Philomena.Topics

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    with {:ok, _topic} <-
           Topics.create_topic_read(
             conn.assigns.actor,
             params["forum_id"],
             params["topic_id"]
           ) do
      send_resp(conn, :ok, "")
    end
  end
end
