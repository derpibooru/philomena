defmodule PhilomenaWeb.Conversation.ReadControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ConversationsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Conversations
  alias Philomena.Repo

  # Unlike the notification-clearing *.ReadControllers, this controller
  # toggles the per-participant read flag on the conversation row and
  # responds with a flash + redirect rather than an empty 200.

  test "anonymous POST redirects to the login page", %{conn: conn} do
    conn = post(conn, ~p"/conversations/dummy-slug/read")
    PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
  end

  test "anonymous DELETE redirects to the login page", %{conn: conn} do
    conn = delete(conn, ~p"/conversations/dummy-slug/read")
    PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
  end

  test "POST as the recipient marks their side read and redirects to the conversation",
       %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), user)
    refute conversation.to_read

    conn = post(conn, ~p"/conversations/#{conversation}/read")

    assert redirected_to(conn) == ~p"/conversations/#{conversation}"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Conversation marked as read."

    conversation = Repo.reload!(conversation)
    assert conversation.to_read
    # the sender's flag is untouched
    assert conversation.from_read
  end

  test "DELETE as the recipient marks their side unread and redirects to the index",
       %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), user)

    {:ok, _} =
      Conversations.update_conversation_read(
        Philomena.AttributionFixtures.actor(user),
        conversation.slug
      )

    conn = delete(conn, ~p"/conversations/#{conversation}/read")

    assert redirected_to(conn) == ~p"/conversations"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Conversation marked as unread."
    refute Repo.reload!(conversation).to_read
  end

  test "DELETE as the sender marks their side unread", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(user, confirmed_user_fixture())
    assert conversation.from_read

    conn = delete(conn, ~p"/conversations/#{conversation}/read")

    assert redirected_to(conn) == ~p"/conversations"

    conversation = Repo.reload!(conversation)
    refute conversation.from_read
    # the recipient's flag is untouched
    refute conversation.to_read
  end

  test "POST as a non-participant redirects to / with the authorization flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

    conn = post(conn, ~p"/conversations/#{conversation}/read")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
  end

  test "POST as a non-participant moderator succeeds but changes neither flag",
       %{conn: conn} do
    # NOTE: moderators pass the :show authorization, but
    # the context only sets flags for the from/to sides, so
    # the action is a flash + redirect no-op for them.
    %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

    conn = post(conn, ~p"/conversations/#{conversation}/read")

    assert redirected_to(conn) == ~p"/conversations/#{conversation}"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Conversation marked as read."

    conversation = Repo.reload!(conversation)
    refute conversation.to_read
    assert conversation.from_read
  end

  test "POST for an unknown conversation redirects with the not-found flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/conversations/unknown-slug/read")

    assert redirected_to(conn) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Couldn't find what you were looking for!"
  end
end
