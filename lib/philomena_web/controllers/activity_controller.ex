defmodule PhilomenaWeb.ActivityController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageScope
  alias Philomena.Activities

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, _params) do
    with {:ok, page} <-
           Activities.show_activity(
             conn.assigns.actor,
             ImageScope.search_scope(conn),
             conn.assigns.current_filter,
             conn.cookies["chan_nsfw"] == "true"
           ) do
      render(
        conn,
        "index.html",
        title: "Homepage",
        images: page.images,
        comments: page.comments,
        top_scoring: page.top_scoring,
        watched: page.watched,
        featured_image: page.featured_image,
        streams: page.streams,
        topics: page.topics,
        interactions: page.interactions,
        layout_class: "layout--wide",
        show_sidebar: show_sidebar?(conn.assigns.current_user)
      )
    end
  end

  defp show_sidebar?(%{settings: %{show_sidebar_and_watched_images: false}}), do: false
  defp show_sidebar?(_user), do: true
end
