defmodule PhilomenaWeb.Topic.SubscriptionController do
  use PhilomenaWeb, :controller

  alias Philomena.Topics

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    case Topics.create_topic_subscription(
           conn.assigns.actor,
           params["forum_id"],
           params["topic_id"]
         ) do
      {:ok, {forum, topic}} ->
        render(conn, "_subscription.html",
          forum: forum,
          topic: topic,
          watching: true,
          layout: false
        )

      {:error, %Ecto.Changeset{}} ->
        render(conn, "_error.html", layout: false)

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, params) do
    with {:ok, {forum, topic}} <-
           Topics.delete_topic_subscription(
             conn.assigns.actor,
             params["forum_id"],
             params["topic_id"]
           ) do
      render(conn, "_subscription.html",
        forum: forum,
        topic: topic,
        watching: false,
        layout: false
      )
    end
  end
end
