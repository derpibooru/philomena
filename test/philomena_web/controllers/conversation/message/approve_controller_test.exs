defmodule PhilomenaWeb.Conversation.Message.ApproveControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ConversationsFixtures
  import Philomena.RulesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo

  # A message whose body contains a markdown image embed (`![`) posted by an
  # untrusted (freshly-registered) user is withheld from approval, giving us
  # something to approve. Posting an unapproved message files a system report
  # against the "Approval" rule, which must exist.
  defp unapproved_message(conn) do
    _rule = rule_fixture(name: "Approval")
    from = confirmed_user_fixture()
    to = confirmed_user_fixture()
    conversation = conversation_fixture(from, to)

    message =
      message_fixture(conversation, from, %{"body" => "look ![here](http://spam.example/x.png)"})

    refute Repo.reload!(message).approved

    {conn, conversation, message}
  end

  describe "POST /conversations/:conversation_id/messages/:message_id/approve" do
    test "redirects anonymous users to login", %{conn: conn} do
      {conn, conversation, message} = unapproved_message(conn)

      conn = post(conn, ~p"/conversations/#{conversation}/messages/#{message}/approve")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
      refute Repo.reload!(message).approved
    end

    test "rejects a regular user", %{conn: conn} do
      {conn, conversation, message} = unapproved_message(conn)
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = post(conn, ~p"/conversations/#{conversation}/messages/#{message}/approve")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.reload!(message).approved
    end

    test "as a moderator approves the message and redirects to /", %{conn: conn} do
      {conn, conversation, message} = unapproved_message(conn)
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/conversations/#{conversation}/messages/#{message}/approve")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Conversation message approved."
      assert Repo.reload!(message).approved
    end

    test "as an admin approves the message", %{conn: conn} do
      {conn, conversation, message} = unapproved_message(conn)
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = post(conn, ~p"/conversations/#{conversation}/messages/#{message}/approve")

      assert redirected_to(conn) == "/"
      assert Repo.reload!(message).approved
    end

    test "approving an already-approved still succeeds", %{conn: conn} do
      from = confirmed_user_fixture()
      to = confirmed_user_fixture()
      conversation = conversation_fixture(from, to)
      # A plain-body reply is approved on creation.
      message = message_fixture(conversation, from, %{"body" => "just a normal reply"})
      assert Repo.reload!(message).approved

      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/conversations/#{conversation}/messages/#{message}/approve")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Conversation message has already been approved."

      assert Repo.reload!(message).approved
    end

    test "for an unknown message_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

      conn = post(conn, ~p"/conversations/#{conversation}/messages/999999999/approve")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer message_id short-circuits to NotFoundPlug via the
    # central IntegerId guard, redirecting with the not-found flash.
    test "for a non-integer message_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

      conn = post(conn, ~p"/conversations/#{conversation}/messages/not-a-number/approve")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    test "for a message belonging to another conversation redirects as not found", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())
      other = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())
      message = message_fixture(other, other.from)

      conn = post(conn, ~p"/conversations/#{conversation}/messages/#{message}/approve")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
