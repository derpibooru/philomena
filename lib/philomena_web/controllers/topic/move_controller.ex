defmodule PhilomenaWeb.Topic.MoveController do
  use PhilomenaWeb, :controller

  alias Philomena.Topics

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    case Topics.create_topic_move(
           conn.assigns.actor,
           params["forum_id"],
           params["topic_id"],
           params["topic"] || %{}
         ) do
      {:ok, {forum, topic}} ->
        conn
        |> put_flash(:info, "Topic successfully moved!")
        |> redirect(to: ~p"/forums/#{forum}/topics/#{topic}")

      {:error, forum, topic} ->
        conn
        |> put_flash(:error, "Unable to move the topic!")
        |> redirect(to: ~p"/forums/#{forum}/topics/#{topic}")

      error ->
        error
    end
  end
end
