defmodule PhilomenaWeb.Conversation.MessageControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.ConversationsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Conversations.Message
  alias Philomena.Repo

  defp message_count(conversation) do
    Repo.aggregate(
      from(message in Message, where: message.conversation_id == ^conversation.id),
      :count
    )
  end

  test "anonymous POST redirects to the login page", %{conn: conn} do
    conn = post(conn, ~p"/conversations/dummy-slug/messages", %{})

    assert redirected_to(conn) == ~p"/sessions/new"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "You must log in to access this page."
  end

  test "POST as a participant creates the message and redirects to the last page",
       %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    sender = confirmed_user_fixture()
    conversation = conversation_fixture(sender, user)

    conn =
      post(conn, ~p"/conversations/#{conversation}/messages", %{
        "message" => %{"body" => "A reply from the recipient"}
      })

    assert redirected_to(conn) == ~p"/conversations/#{conversation}?#{[page: 1]}"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Message successfully sent."

    assert message_count(conversation) == 2

    # a new message marks both sides unread again
    conversation = Repo.reload!(conversation)
    refute conversation.from_read
    refute conversation.to_read
  end

  test "POST with an empty body re-renders the conversation with errors", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), user)

    conn =
      post(conn, ~p"/conversations/#{conversation}/messages", %{
        "message" => %{"body" => ""}
      })

    response = html_response(conn, 200)
    assert response =~ conversation.title
    assert response =~ "can&#39;t be blank"
    assert message_count(conversation) == 1
  end

  test "POST without a message re-renders the conversation with errors", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), user)

    conn = post(conn, ~p"/conversations/#{conversation}/messages", %{})

    assert html_response(conn, 200) =~ "can&#39;t be blank"
    assert message_count(conversation) == 1
  end

  test "POST as a non-participant moderator creates the message", %{conn: conn} do
    # NOTE: create maps to the :show ability, so any moderator can post
    # into any conversation.
    %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

    conn =
      post(conn, ~p"/conversations/#{conversation}/messages", %{
        "message" => %{"body" => "Moderator interjection"}
      })

    assert redirected_to(conn) == ~p"/conversations/#{conversation}?#{[page: 1]}"
    assert message_count(conversation) == 2
  end

  test "POST as a non-participant redirects to / with the authorization flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

    conn =
      post(conn, ~p"/conversations/#{conversation}/messages", %{
        "message" => %{"body" => "Should not appear"}
      })

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    assert message_count(conversation) == 1
  end

  test "POST for an unknown conversation redirects with the not-found flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn =
      post(conn, ~p"/conversations/unknown-slug/messages", %{
        "message" => %{"body" => "Should not appear"}
      })

    assert redirected_to(conn) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Couldn't find what you were looking for!"
  end

  test "POST as a banned user redirects with the ban flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

    conn =
      post(conn, ~p"/conversations/dummy-slug/messages", %{
        "message" => %{"body" => "Should not appear"}
      })

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
  end
end
