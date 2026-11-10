defmodule PhilomenaWeb.TopicController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.NotificationCountPlug
  alias PhilomenaWeb.MarkdownRenderer
  alias PhilomenaWeb.RateLimitedResponse
  alias Philomena.Forums.Forum
  alias Philomena.Topics

  plug PhilomenaWeb.AdvertPlug when action in [:show]

  action_fallback PhilomenaWeb.FallbackController

  def show(conn, %{"forum_id" => forum_id, "id" => id} = params) do
    with {:ok, page} <-
           Topics.show_topic_page(
             conn.assigns.actor,
             forum_id,
             id,
             params["post_id"],
             conn.assigns.pagination
           ) do
      # The page load cleared the topic's notifications; refresh the header
      # notification ticker afterwards so it reflects the cleared state.
      conn = NotificationCountPlug.call(conn)

      rendered = MarkdownRenderer.render_collection(page.posts.entries, conn)
      posts = %{page.posts | entries: Enum.zip(page.posts.entries, rendered)}

      conn
      |> assign(:forum, page.forum)
      |> assign(:topic, page.topic)
      |> render("show.html",
        title: "#{page.topic.title} - #{page.forum.name} - Forums",
        posts: posts,
        changeset: page.post_changeset,
        topic_changeset: page.topic_changeset,
        watching: page.watching,
        voted: page.voted,
        poll_active: page.poll_active
      )
    end
  end

  def new(conn, %{"forum_id" => forum_id}) do
    with {:ok, {forum, changeset}} <- Topics.new_topic(conn.assigns.actor, forum_id) do
      conn
      |> assign(:forum, forum)
      |> render("new.html", title: "New Topic", changeset: changeset)
    end
  end

  def create(conn, %{"forum_id" => forum_id} = params) do
    case Topics.create_topic(conn.assigns.actor, forum_id, params["topic"]) do
      {:ok, %{topic: topic, forum: forum}} ->
        conn
        |> put_flash(:info, "Successfully posted topic.")
        |> redirect(to: ~p"/forums/#{forum}/topics/#{topic}")

      {:error, %Forum{} = forum, changeset} ->
        conn
        |> assign(:forum, forum)
        |> render("new.html", changeset: changeset)

      {:error, :rate_limited} ->
        RateLimitedResponse.call(conn, "You may only make a new topic once every 5 minutes.")

      error ->
        error
    end
  end

  def update(conn, %{"forum_id" => forum_id, "id" => id, "topic" => topic_params}) do
    case Topics.update_topic(conn.assigns.actor, forum_id, id, topic_params) do
      {:ok, {forum, topic}} ->
        conn
        |> put_flash(:info, "Successfully updated topic.")
        |> redirect(to: ~p"/forums/#{forum}/topics/#{topic}")

      {:error, forum, topic} ->
        conn
        |> put_flash(:error, "There was an error with your submission. Please try again.")
        |> redirect(to: ~p"/forums/#{forum}/topics/#{topic}")

      error ->
        error
    end
  end
end
