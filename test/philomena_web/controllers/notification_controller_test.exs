defmodule PhilomenaWeb.NotificationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.CommentsFixtures
  import Philomena.ForumsFixtures
  import Philomena.ImagesFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Forums
  alias Philomena.Images
  alias Philomena.Notifications

  test "anonymous GET /notifications redirects to the login page", %{conn: conn} do
    conn = get(conn, ~p"/notifications")

    assert redirected_to(conn) == ~p"/sessions/new"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "You must log in to access this page."
  end

  test "GET /notifications with no notifications renders the empty notification area",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    response = html_response(get(conn, ~p"/notifications"), 200)

    assert response =~ "Notification Area - Derpibooru"
    refute response =~ "View category ("
  end

  test "GET /notifications groups unread notifications by category", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

    # forum_topic: user watches a forum, someone posts a topic in it
    forum = forum_fixture()
    {:ok, _} = Forums.create_subscription(forum, user)
    author = confirmed_user_fixture()
    topic = topic_fixture(forum, author)
    {:ok, 1} = Notifications.broadcast_forum_topic(author, topic)

    # image_comment: user watches an image, someone comments on it
    image = image_fixture()
    {:ok, _} = Images.create_subscription(image, user)
    comment = comment_fixture(image, author)
    {:ok, 1} = Notifications.broadcast_image_comment(author, image, comment)

    response = html_response(get(conn, ~p"/notifications"), 200)

    assert response =~ "New topics"
    assert response =~ topic.title
    assert response =~ ~p"/notifications/categories/forum_topic"
    assert response =~ "New replies on images"
    assert response =~ ~p"/notifications/categories/image_comment"
  end

  test "GET /notifications does not show other users' notifications", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    forum = forum_fixture()
    recipient = confirmed_user_fixture()
    {:ok, _} = Forums.create_subscription(forum, recipient)
    author = confirmed_user_fixture()
    topic = topic_fixture(forum, author)
    {:ok, 1} = Notifications.broadcast_forum_topic(author, topic)

    response = html_response(get(conn, ~p"/notifications"), 200)

    refute response =~ topic.title
  end

  test "DELETE /notifications/:id is no longer routed and answers 404", %{conn: conn} do
    # NOTE: the notifications resource now routes only :index, so this path is
    # unrouted and answers 404 (notification clearing happens through the
    # per-type read controllers instead).
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = delete(conn, "/notifications/1")

    assert conn.status == 404
  end
end
