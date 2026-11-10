defmodule PhilomenaWeb.Notification.UnreadControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ConversationsFixtures
  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Forums
  alias Philomena.Notifications

  test "anonymous GET redirects to the login page", %{conn: conn} do
    conn = get(conn, ~p"/notifications/unread")

    assert redirected_to(conn) == ~p"/sessions/new"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "You must log in to access this page."
  end

  test "GET with nothing unread returns zero counts", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    assert json_response(get(conn, ~p"/notifications/unread"), 200) == %{
             "notifications" => 0,
             "conversations" => 0
           }
  end

  test "GET returns the unread notification and conversation counts", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

    forum = forum_fixture()
    {:ok, _} = Forums.create_subscription(forum, user)
    author = confirmed_user_fixture()
    topic = topic_fixture(forum, author)
    {:ok, 1} = Notifications.broadcast_forum_topic(author, topic)

    _conversation = conversation_fixture(confirmed_user_fixture(), user)

    assert json_response(get(conn, ~p"/notifications/unread"), 200) == %{
             "notifications" => 1,
             "conversations" => 1
           }
  end
end
