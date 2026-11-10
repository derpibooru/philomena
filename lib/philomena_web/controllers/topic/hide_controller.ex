defmodule PhilomenaWeb.Topic.HideController do
  use PhilomenaWeb, :controller

  alias Philomena.Topics

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    case Topics.create_topic_hide(
           conn.assigns.actor,
           params["forum_id"],
           params["topic_id"],
           params["topic"] || %{}
         ) do
      {:ok, {forum, topic}} ->
        conn
        |> put_flash(:info, "Topic successfully deleted!")
        |> redirect(to: ~p"/forums/#{forum}/topics/#{topic}")

      {:error, forum, topic} ->
        conn
        |> put_flash(:error, "Unable to delete the topic!")
        |> redirect(to: ~p"/forums/#{forum}/topics/#{topic}")

      error ->
        error
    end
  end

  def delete(conn, params) do
    case Topics.delete_topic_hide(
           conn.assigns.actor,
           params["forum_id"],
           params["topic_id"]
         ) do
      {:ok, {forum, topic}} ->
        conn
        |> put_flash(:info, "Topic successfully restored!")
        |> redirect(to: ~p"/forums/#{forum}/topics/#{topic}")

      {:error, forum, topic} ->
        conn
        |> put_flash(:error, "Unable to restore the topic!")
        |> redirect(to: ~p"/forums/#{forum}/topics/#{topic}")

      error ->
        error
    end
  end
end
