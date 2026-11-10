defmodule PhilomenaWeb.Notification.CategoryControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Forums
  alias Philomena.Notifications

  test "anonymous GET redirects to the login page", %{conn: conn} do
    conn = get(conn, ~p"/notifications/categories/forum_topic")

    assert redirected_to(conn) == ~p"/sessions/new"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "You must log in to access this page."
  end

  test "GET lists the user's unread notifications in the category", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

    forum = forum_fixture()
    {:ok, _} = Forums.create_subscription(forum, user)
    author = confirmed_user_fixture()
    topic = topic_fixture(forum, author)
    {:ok, 1} = Notifications.broadcast_forum_topic(author, topic)

    response = html_response(get(conn, ~p"/notifications/categories/forum_topic"), 200)

    assert response =~ "Notification Area - Derpibooru"
    assert response =~ "New topics"
    assert response =~ topic.title
  end

  test "GET with no notifications in the category renders the empty message", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    response = html_response(get(conn, ~p"/notifications/categories/forum_topic"), 200)

    assert response =~ "You currently have no notifications of this category."
  end

  test "GET with an unknown category id follows the site's not-found response", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = get(conn, ~p"/notifications/categories/bogus-category")

    assert redirected_to(conn) == ~p"/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Couldn't find what you were looking for!"
  end
end
