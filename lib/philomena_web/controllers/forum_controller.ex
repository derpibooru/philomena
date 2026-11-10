defmodule PhilomenaWeb.ForumController do
  use PhilomenaWeb, :controller

  alias Philomena.Forums

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, _params) do
    index = Forums.list_forums(conn.assigns.actor, conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Forums",
      forums: index.forums,
      topic_count: index.topic_count
    )
  end

  def show(conn, %{"id" => short_name}) do
    with {:ok, page} <-
           Forums.show_forum_page(conn.assigns.actor, short_name, conn.assigns.scrivener) do
      render(conn, "show.html",
        title: page.forum.name,
        forum: page.forum,
        watching: page.watching,
        topics: page.topics
      )
    end
  end
end
