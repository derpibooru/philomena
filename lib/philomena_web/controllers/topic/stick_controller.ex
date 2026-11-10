defmodule PhilomenaWeb.Topic.StickController do
  use PhilomenaWeb, :controller

  alias Philomena.Topics

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    case Topics.create_topic_stick(
           conn.assigns.actor,
           params["forum_id"],
           params["topic_id"]
         ) do
      {:ok, {forum, topic}} ->
        conn
        |> put_flash(:info, "Topic successfully stickied!")
        |> redirect(to: ~p"/forums/#{forum}/topics/#{topic}")

      {:error, forum, topic} ->
        conn
        |> put_flash(:error, "Unable to stick the topic!")
        |> redirect(to: ~p"/forums/#{forum}/topics/#{topic}")

      error ->
        error
    end
  end

  def delete(conn, params) do
    case Topics.delete_topic_stick(
           conn.assigns.actor,
           params["forum_id"],
           params["topic_id"]
         ) do
      {:ok, {forum, topic}} ->
        conn
        |> put_flash(:info, "Topic successfully unstickied!")
        |> redirect(to: ~p"/forums/#{forum}/topics/#{topic}")

      {:error, forum, topic} ->
        conn
        |> put_flash(:error, "Unable to unstick the topic!")
        |> redirect(to: ~p"/forums/#{forum}/topics/#{topic}")

      error ->
        error
    end
  end
end
