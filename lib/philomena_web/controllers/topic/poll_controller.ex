defmodule PhilomenaWeb.Topic.PollController do
  use PhilomenaWeb, :controller

  alias Philomena.Polls

  action_fallback PhilomenaWeb.FallbackController

  def edit(conn, %{"forum_id" => forum_slug, "topic_id" => topic_slug}) do
    with {:ok, %Ecto.Changeset{data: poll} = changeset} <-
           Polls.edit_poll(conn.assigns.actor, forum_slug, topic_slug) do
      render(conn, "edit.html",
        title: "Editing Poll",
        forum: poll.topic.forum,
        topic: poll.topic,
        poll: poll,
        changeset: changeset
      )
    end
  end

  def update(conn, %{"forum_id" => forum_slug, "topic_id" => topic_slug, "poll" => poll_params}) do
    case Polls.update_poll(conn.assigns.actor, forum_slug, topic_slug, poll_params) do
      {:ok, poll} ->
        conn
        |> put_flash(:info, "Poll successfully updated.")
        |> redirect(to: ~p"/forums/#{poll.topic.forum}/topics/#{poll.topic}")

      {:error, %Ecto.Changeset{data: poll} = changeset} ->
        render(conn, "edit.html",
          forum: poll.topic.forum,
          topic: poll.topic,
          poll: poll,
          changeset: changeset
        )

      error ->
        error
    end
  end
end
