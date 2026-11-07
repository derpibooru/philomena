defmodule PhilomenaWeb.ConversationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ConversationsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Conversations.Conversation
  alias Philomena.Repo
  import Ecto.Query

  test "anonymous requests redirect to the login page", %{conn: conn} do
    for request <- [
          get(conn, ~p"/conversations"),
          get(conn, ~p"/conversations/new"),
          get(conn, ~p"/conversations/dummy-slug"),
          post(conn, ~p"/conversations", %{})
        ] do
      assert redirected_to(request) == ~p"/sessions/new"

      assert Phoenix.Flash.get(request.assigns.flash, :error) ==
               "You must log in to access this page."
    end
  end

  test "GET /conversations lists the user's conversations but not others'", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    received = conversation_fixture(confirmed_user_fixture(), user)
    sent = conversation_fixture(user, confirmed_user_fixture())
    unrelated = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

    response = html_response(get(conn, ~p"/conversations"), 200)

    assert response =~ "Conversations - Derpibooru"
    assert response =~ "My Conversations"
    assert response =~ received.title
    assert response =~ sent.title
    refute response =~ unrelated.title
  end

  test "GET /conversations does not list conversations the user has hidden", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    hidden = conversation_fixture(confirmed_user_fixture(), user)

    {:ok, _} =
      Philomena.Conversations.update_conversation_hide(
        Philomena.AttributionFixtures.actor(user),
        hidden.slug
      )

    response = html_response(get(conn, ~p"/conversations"), 200)

    refute response =~ hidden.title
  end

  test "GET /conversations/new renders the form", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    response = html_response(get(conn, ~p"/conversations/new"), 200)

    assert response =~ "New Conversation - Derpibooru"
  end

  test "GET /conversations/:id as the recipient renders the messages and marks their side read",
       %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    sender = confirmed_user_fixture()
    conversation = conversation_fixture(sender, user)
    refute conversation.to_read

    response = html_response(get(conn, ~p"/conversations/#{conversation}"), 200)

    assert response =~ conversation.title
    assert response =~ "Test message body"
    assert response =~ sender.name
    assert Repo.reload!(conversation).to_read
  end

  test "pending messages disclose their body only to the sender or an approver", %{conn: conn} do
    sender = confirmed_user_fixture(%{name: "Pending Sender"})
    recipient = confirmed_user_fixture(%{name: "Pending Recipient"})
    conversation = conversation_fixture(sender, recipient)
    message = message_fixture(conversation, sender, %{"body" => "Private pending body"})

    Repo.update!(Ecto.Changeset.change(message, approved: false))

    sender_response =
      html_response(get(log_in_user(conn, sender), ~p"/conversations/#{conversation}"), 200)

    assert sender_response =~ "pending approval from a staff member"
    assert sender_response =~ "Private pending body"

    refute sender_response =~
             ~p"/conversations/#{conversation}/messages/#{message}/approve"

    recipient_response =
      html_response(get(log_in_user(conn, recipient), ~p"/conversations/#{conversation}"), 200)

    refute recipient_response =~ "Private pending body"

    refute recipient_response =~
             ~p"/conversations/#{conversation}/messages/#{message}/approve"

    moderator_response =
      html_response(
        get(log_in_user(conn, moderator_user_fixture()), ~p"/conversations/#{conversation}"),
        200
      )

    assert moderator_response =~ "Private pending body"

    assert moderator_response =~
             ~p"/conversations/#{conversation}/messages/#{message}/approve"

    assert moderator_response =~ "Approve"
  end

  test "GET /conversations/:id as a non-participant moderator renders the conversation",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

    response = html_response(get(conn, ~p"/conversations/#{conversation}"), 200)

    assert response =~ conversation.title
  end

  test "GET /conversations/:id as a non-participant redirects to / with the authorization flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

    conn = get(conn, ~p"/conversations/#{conversation}")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
  end

  test "GET /conversations/:id for an unknown slug redirects with the not-found flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = get(conn, ~p"/conversations/unknown-slug")

    assert redirected_to(conn) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Couldn't find what you were looking for!"
  end

  test "GET /conversations with a malformed partner filter renders an empty index", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    response = html_response(get(conn, ~p"/conversations?#{[with: "not-a-number"]}"), 200)

    assert response =~ "My Conversations"
    assert response =~ "Invalid conversation filter."
  end

  test "POST /conversations creates the conversation and first message", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    recipient = confirmed_user_fixture()

    conn =
      post(conn, ~p"/conversations", %{
        "conversation" => %{
          "recipient" => recipient.name,
          "title" => "Hello there",
          "messages" => %{"0" => %{"body" => "A fine day to you"}}
        }
      })

    conversation =
      Repo.one!(from c in Conversation, where: c.from_id == ^user.id)
      |> Repo.preload(:messages)

    assert redirected_to(conn) == ~p"/conversations/#{conversation}"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Conversation successfully created."
    assert conversation.title == "Hello there"
    assert conversation.to_id == recipient.id
    assert [%{body: "A fine day to you"}] = conversation.messages
  end

  test "POST /conversations with an unknown recipient re-renders the form", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

    conn =
      post(conn, ~p"/conversations", %{
        "conversation" => %{
          "recipient" => "nobody by this name",
          "title" => "Hello there",
          "messages" => %{"0" => %{"body" => "A fine day to you"}}
        }
      })

    response = html_response(conn, 200)
    assert response =~ "New Conversation"
    assert Repo.aggregate(from(c in Conversation, where: c.from_id == ^user.id), :count) == 0
  end

  test "POST /conversations without a conversation re-renders the form", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/conversations", %{})

    assert html_response(conn, 200) =~ "New Conversation"
    assert Repo.aggregate(from(c in Conversation, where: c.from_id == ^user.id), :count) == 0
  end

  test "POST /conversations with non-map params raises", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    assert_raise Ecto.CastError, fn ->
      post(conn, ~p"/conversations", %{"conversation" => "invalid"})
    end
  end

  test "POST /conversations as a banned user redirects with the ban flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

    conn =
      post(conn, ~p"/conversations", %{
        "conversation" => %{
          "recipient" => confirmed_user_fixture().name,
          "title" => "Hello there",
          "messages" => %{"0" => %{"body" => "A fine day to you"}}
        }
      })

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
  end

  test "GET /conversations/new renders the form without a fingerprint", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = get(without_fingerprint(conn), ~p"/conversations/new")

    assert html_response(conn, 200) =~ "New Conversation - Derpibooru"
  end

  test "POST /conversations without a fingerprint redirects to / with the authorization flash",
       %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

    conn =
      post(without_fingerprint(conn), ~p"/conversations", %{
        "conversation" => %{
          "recipient" => confirmed_user_fixture().name,
          "title" => "Hello there",
          "messages" => %{"0" => %{"body" => "A fine day to you"}}
        }
      })

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    refute Repo.exists?(from c in Conversation, where: c.from_id == ^user.id)
  end
end
