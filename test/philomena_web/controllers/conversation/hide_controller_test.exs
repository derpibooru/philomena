defmodule PhilomenaWeb.Conversation.HideControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ConversationsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Conversations
  alias Philomena.Repo

  test "anonymous POST redirects to the login page", %{conn: conn} do
    conn = post(conn, ~p"/conversations/dummy-slug/hide")
    PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
  end

  test "anonymous DELETE redirects to the login page", %{conn: conn} do
    conn = delete(conn, ~p"/conversations/dummy-slug/hide")
    PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
  end

  test "POST as the recipient hides their side and redirects to the index", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), user)

    conn = post(conn, ~p"/conversations/#{conversation}/hide")

    assert redirected_to(conn) == ~p"/conversations"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Conversation hidden."

    conversation = Repo.reload!(conversation)
    assert conversation.to_hidden
    # the sender's flag is untouched
    refute conversation.from_hidden
  end

  test "POST as the sender hides their side", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(user, confirmed_user_fixture())

    conn = post(conn, ~p"/conversations/#{conversation}/hide")

    assert redirected_to(conn) == ~p"/conversations"

    conversation = Repo.reload!(conversation)
    assert conversation.from_hidden
    refute conversation.to_hidden
  end

  test "DELETE as the recipient restores their side and redirects to the conversation",
       %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), user)

    {:ok, _} =
      Conversations.update_conversation_hide(
        Philomena.AttributionFixtures.actor(user),
        conversation.slug
      )

    conn = delete(conn, ~p"/conversations/#{conversation}/hide")

    assert redirected_to(conn) == ~p"/conversations/#{conversation}"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Conversation restored."
    refute Repo.reload!(conversation).to_hidden
  end

  test "POST as a non-participant redirects to / with the authorization flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

    conn = post(conn, ~p"/conversations/#{conversation}/hide")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
  end

  test "POST for an unknown conversation redirects with the not-found flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/conversations/unknown-slug/hide")

    assert redirected_to(conn) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Couldn't find what you were looking for!"
  end
end
