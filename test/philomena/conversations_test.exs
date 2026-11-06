defmodule Philomena.ConversationsTest do
  @moduledoc """
  Context-level tests for the controller-facing `Philomena.Conversations`
  functions.

  These pin typed index/form/message results, load-before-authorize missing
  behavior, participant/staff abilities, form/write prerequisite parity,
  normalized parameters, idempotent personal state, parent-scoped approval,
  and transactional approval logging.
  """

  use Philomena.DataCase, async: true

  import Philomena.ConversationsFixtures
  import Philomena.RulesFixtures
  import Philomena.AttributionFixtures
  import Philomena.UsersFixtures

  alias Philomena.Conversations
  alias Philomena.Conversations.Conversation
  alias Philomena.Conversations.ConversationIndex
  alias Philomena.Conversations.ConversationPage
  alias Philomena.Conversations.Message
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Repo
  alias Philomena.Reports.Report

  # A truthy ban value in the shape production passes (the result of
  # Philomena.Bans.find/3); only its presence matters to the write-access and
  # not-banned checks the write paths run first.
  @ban %{
    reason: "Rule #0",
    valid_until: ~U[3000-01-01 00:00:00Z],
    generated_ban_id: "U123456",
    type: "User"
  }

  @pagination %{page_number: 1, page_size: 25}

  # A message body whose markdown image embed causes an untrusted sender's
  # message to be withheld from approval. Posting it files a system report
  # against the "Approval" rule, which must exist.
  @spam_body "look ![here](http://spam.example/x.png)"

  defp only_moderation_log!, do: Repo.one!(ModerationLog)

  # Builds a conversation with a single unapproved reply, returning the reply.
  defp unapproved_message(from, to) do
    _rule = rule_fixture(name: "Approval")
    conversation = conversation_fixture(from, to)
    message = message_fixture(conversation, from, %{"body" => @spam_body})
    refute Repo.reload!(message).approved
    {conversation, message}
  end

  describe "list_conversations/3" do
    test "sorts unread conversations first from the actor's perspective" do
      user = confirmed_user_fixture()
      received = conversation_fixture(confirmed_user_fixture(), user)
      sent = conversation_fixture(user, confirmed_user_fixture())
      read = conversation_fixture(confirmed_user_fixture(), user)
      {:ok, _} = Conversations.update_conversation_read(actor(user), sent.slug, false)
      {:ok, _} = Conversations.update_conversation_read(actor(user), read.slug)

      assert {:ok, index} = Conversations.list_conversations(actor(user), %{}, @pagination)
      assert Enum.map(index.conversations.entries, & &1.id) == [sent.id, received.id, read.id]
    end

    test "lists the user's sent and received conversations but not unrelated ones" do
      user = confirmed_user_fixture()
      received = conversation_fixture(confirmed_user_fixture(), user)
      sent = conversation_fixture(user, confirmed_user_fixture())
      unrelated = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

      assert {:ok, %ConversationIndex{} = index} =
               Conversations.list_conversations(actor(user), %{}, @pagination)

      ids = Enum.map(index.conversations.entries, & &1.id)
      assert received.id in ids
      assert sent.id in ids
      refute unrelated.id in ids
    end

    test "does not list conversations the user has hidden" do
      user = confirmed_user_fixture()
      hidden = conversation_fixture(confirmed_user_fixture(), user)
      {:ok, _} = Conversations.update_conversation_hide(actor(user), hidden.slug)

      assert {:ok, %ConversationIndex{} = index} =
               Conversations.list_conversations(actor(user), %{}, @pagination)

      refute hidden.id in Enum.map(index.conversations.entries, & &1.id)
    end

    test "a with filter restricts the list to the named partner" do
      user = confirmed_user_fixture()
      partner = confirmed_user_fixture()
      with_partner = conversation_fixture(partner, user)
      other = conversation_fixture(confirmed_user_fixture(), user)

      assert {:ok, %ConversationIndex{} = index} =
               Conversations.list_conversations(
                 actor(user),
                 %{"with" => "#{partner.id}"},
                 @pagination
               )

      ids = Enum.map(index.conversations.entries, & &1.id)
      assert with_partner.id in ids
      refute other.id in ids
    end

    test "malformed and out-of-range filters return a blank page and invalid changeset" do
      user = confirmed_user_fixture()

      for filter <- ["not-a-number", "99999999999999999999"] do
        assert {:ok, %ConversationIndex{} = index} =
                 Conversations.list_conversations(
                   actor(user),
                   %{"with" => filter},
                   @pagination
                 )

        assert index.conversations == nil
        refute index.changeset.valid?
      end
    end

    test "anonymous actors are unauthorized" do
      assert Conversations.list_conversations(actor(), %{}, @pagination) ==
               {:error, :unauthorized}
    end
  end

  describe "unread_conversation_count/1" do
    test "counts unread visible conversations and excludes hidden ones" do
      user = confirmed_user_fixture()
      unread = conversation_fixture(confirmed_user_fixture(), user)
      hidden = conversation_fixture(confirmed_user_fixture(), user)
      {:ok, _} = Conversations.update_conversation_hide(actor(user), hidden.slug)

      assert {:ok, 1} = Conversations.unread_conversation_count(actor(user))
      assert unread.id != hidden.id
    end

    test "anonymous actors are unauthorized" do
      assert Conversations.unread_conversation_count(actor()) == {:error, :unauthorized}
    end
  end

  describe "show_conversation/3" do
    test "the recipient loads the page, its messages, and marks their side read" do
      sender = confirmed_user_fixture()
      recipient = confirmed_user_fixture()
      conversation = conversation_fixture(sender, recipient)
      refute conversation.to_read

      assert {:ok, %ConversationPage{} = page} =
               Conversations.show_conversation(
                 actor(recipient),
                 conversation.slug,
                 @pagination
               )

      assert page.conversation.id == conversation.id
      assert %Ecto.Changeset{data: %Message{}} = page.changeset
      assert Enum.any?(page.messages.entries, &(&1.body == "Test message body"))

      # The recipient's side of the conversation is marked read as a side effect.
      assert Repo.reload!(conversation).to_read
    end

    test "a non-participant moderator loads the page" do
      conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

      assert {:ok, %ConversationPage{}} =
               Conversations.show_conversation(
                 actor(moderator_user_fixture()),
                 conversation.slug,
                 @pagination
               )
    end

    test "a non-participant regular user is unauthorized" do
      conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

      assert Conversations.show_conversation(
               actor(confirmed_user_fixture()),
               conversation.slug,
               @pagination
             ) == {:error, :unauthorized}
    end

    test "an unknown slug is not found for users, moderators, and admins" do
      for viewer <- [
            confirmed_user_fixture(),
            moderator_user_fixture(),
            admin_user_fixture()
          ] do
        assert Conversations.show_conversation(
                 actor(viewer),
                 "no-such-slug",
                 @pagination
               ) == {:error, :not_found}
      end
    end
  end

  describe "new_conversation/2" do
    test "a signed-in actor gets a changeset prefilled with the recipient" do
      recipient = confirmed_user_fixture()

      assert {:ok, %Ecto.Changeset{} = changeset} =
               Conversations.new_conversation(
                 actor(confirmed_user_fixture()),
                 %{"recipient" => recipient.name}
               )

      assert fetch_change!(changeset, :recipient) == recipient.name
    end

    test "a banned actor is rejected even while carrying a fingerprint" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Conversations.new_conversation(actor, %{"recipient" => "anyone"}) == {:error, :ban}
    end

    test "an actor without a fingerprint still reaches the form" do
      actor = actor(confirmed_user_fixture(), fingerprint: nil)

      assert {:ok, _} = Conversations.new_conversation(actor, %{"recipient" => "anyone"})
    end
  end

  describe "trusted_sender?/1" do
    test "uses conversation approval eligibility for anonymous, new, and verified actors" do
      refute Conversations.trusted_sender?(actor())
      refute Conversations.trusted_sender?(actor(confirmed_user_fixture()))
      assert Conversations.trusted_sender?(actor(verified_user_fixture()))
      assert Conversations.trusted_sender?(actor(moderator_user_fixture()))
    end
  end

  describe "create_conversation/2" do
    test "a signed-in actor creates a conversation and its first message" do
      user = confirmed_user_fixture()
      recipient = confirmed_user_fixture()

      params = %{
        "recipient" => recipient.name,
        "title" => "Hello there",
        "messages" => %{"0" => %{"body" => "A fine day to you"}}
      }

      assert {:ok, %Conversation{} = conversation} =
               Conversations.create_conversation(actor(user), params)

      assert conversation.from_id == user.id
      assert conversation.to_id == recipient.id
      assert conversation.title == "Hello there"
    end

    test "an unknown recipient is a rejected changeset" do
      params = %{
        "recipient" => "nobody by this name",
        "title" => "Hello there",
        "messages" => %{"0" => %{"body" => "A fine day to you"}}
      }

      assert {:error, %Ecto.Changeset{} = changeset} =
               Conversations.create_conversation(actor(confirmed_user_fixture()), params)

      refute changeset.valid?
    end

    test "a deactivated recipient is a rejected changeset" do
      sender = confirmed_user_fixture()
      recipient = deactivated_user_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Conversations.create_conversation(actor(sender), %{
                 "recipient" => recipient.name,
                 "title" => "Hello",
                 "messages" => %{"0" => %{"body" => "Hello"}}
               })

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:to]
    end

    test "non-map params raise" do
      assert_raise Ecto.CastError,
                   fn ->
                     Conversations.create_conversation(actor(confirmed_user_fixture()), "invalid")
                   end
    end

    test "a banned actor is rejected" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Conversations.create_conversation(actor, %{"recipient" => "anyone"}) ==
               {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized" do
      actor = actor(confirmed_user_fixture(), fingerprint: nil)

      assert Conversations.create_conversation(actor, %{"recipient" => "anyone"}) ==
               {:error, :unauthorized}
    end

    test "the ban wins over a missing fingerprint" do
      actor = actor(confirmed_user_fixture(), ban: @ban, fingerprint: nil)

      assert Conversations.create_conversation(actor, %{"recipient" => "anyone"}) ==
               {:error, :ban}
    end

    test "an over-limit actor is rate limited and no conversation is created" do
      # The :conversation_create counter is primed past the limit, so the
      # rate check (after write-access, before the insert) refuses the write.
      user = confirmed_user_fixture()
      recipient = confirmed_user_fixture()
      actor = actor(user)
      exceed_rate_limit(actor, :conversation_create)

      params = %{
        "recipient" => recipient.name,
        "title" => "Hello there",
        "messages" => %{"0" => %{"body" => "A fine day to you"}}
      }

      assert Conversations.create_conversation(actor, params) == {:error, :rate_limited}
      assert Repo.aggregate(Conversation, :count) == 0
    end

    test "a successful create records the counter" do
      user = confirmed_user_fixture()
      recipient = confirmed_user_fixture()
      actor = actor(user)
      track_rate_limit(actor, :conversation_create)

      params = %{
        "recipient" => recipient.name,
        "title" => "Hello there",
        "messages" => %{"0" => %{"body" => "A fine day to you"}}
      }

      assert {:ok, %Conversation{}} = Conversations.create_conversation(actor, params)
      assert rate_limit_count(actor, :conversation_create) == "1"
    end

    test "invalid recipient input does not consume the rate limit" do
      actor = actor(confirmed_user_fixture())
      exceed_rate_limit(actor, :conversation_create)

      assert {:error, %Ecto.Changeset{}} =
               Conversations.create_conversation(actor, %{"recipient" => "nobody by this name"})
    end
  end

  describe "update_conversation_read/2 and update_conversation_read/3" do
    test "the recipient marks their conversation read then unread" do
      sender = confirmed_user_fixture()
      recipient = confirmed_user_fixture()
      conversation = conversation_fixture(sender, recipient)

      assert {:ok, %Conversation{}} =
               Conversations.update_conversation_read(actor(recipient), conversation.slug)

      assert Repo.reload!(conversation).to_read

      assert {:ok, %Conversation{}} =
               Conversations.update_conversation_read(actor(recipient), conversation.slug, false)

      refute Repo.reload!(conversation).to_read
    end

    test "a non-participant moderator succeeds without changing either read flag" do
      # The moderator is authorized for :show but is not a participant, so the
      # read flag is set for neither side.
      sender = confirmed_user_fixture()
      recipient = confirmed_user_fixture()
      conversation = conversation_fixture(sender, recipient)

      assert {:ok, %Conversation{}} =
               Conversations.update_conversation_read(
                 actor(moderator_user_fixture()),
                 conversation.slug
               )

      reloaded = Repo.reload!(conversation)
      refute reloaded.to_read
      assert reloaded.from_read
    end

    test "a non-participant regular user is unauthorized" do
      conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

      assert Conversations.update_conversation_read(
               actor(confirmed_user_fixture()),
               conversation.slug
             ) ==
               {:error, :unauthorized}
    end

    test "repeated updates are idempotent" do
      recipient = confirmed_user_fixture()
      conversation = conversation_fixture(confirmed_user_fixture(), recipient)

      assert {:ok, %Conversation{}} =
               Conversations.update_conversation_read(actor(recipient), conversation.slug)

      assert {:ok, %Conversation{}} =
               Conversations.update_conversation_read(actor(recipient), conversation.slug)

      assert Repo.reload!(conversation).to_read
    end

    test "an unknown slug is always not found" do
      for viewer <- [confirmed_user_fixture(), admin_user_fixture()] do
        assert Conversations.update_conversation_read(actor(viewer), "no-such-slug") ==
                 {:error, :not_found}
      end
    end
  end

  describe "update_conversation_hide/2 and update_conversation_hide/3" do
    test "the recipient hides then restores their conversation" do
      sender = confirmed_user_fixture()
      recipient = confirmed_user_fixture()
      conversation = conversation_fixture(sender, recipient)

      assert {:ok, %Conversation{}} =
               Conversations.update_conversation_hide(actor(recipient), conversation.slug)

      assert Repo.reload!(conversation).to_hidden

      assert {:ok, %Conversation{}} =
               Conversations.update_conversation_hide(actor(recipient), conversation.slug, false)

      refute Repo.reload!(conversation).to_hidden
    end

    test "a non-participant regular user is unauthorized" do
      conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

      assert Conversations.update_conversation_hide(
               actor(confirmed_user_fixture()),
               conversation.slug
             ) ==
               {:error, :unauthorized}
    end

    test "repeated updates are idempotent" do
      recipient = confirmed_user_fixture()
      conversation = conversation_fixture(confirmed_user_fixture(), recipient)

      assert {:ok, %Conversation{}} =
               Conversations.update_conversation_hide(actor(recipient), conversation.slug)

      assert {:ok, %Conversation{}} =
               Conversations.update_conversation_hide(actor(recipient), conversation.slug)

      assert Repo.reload!(conversation).to_hidden
    end

    test "an unknown slug is always not found" do
      for viewer <- [confirmed_user_fixture(), admin_user_fixture()] do
        assert Conversations.update_conversation_hide(actor(viewer), "no-such-slug") ==
                 {:error, :not_found}
      end
    end
  end

  describe "create_message/3" do
    test "a participant posts a reply and both sides are marked unread" do
      sender = confirmed_user_fixture()
      recipient = confirmed_user_fixture()
      conversation = conversation_fixture(sender, recipient)
      # The recipient reads the conversation, clearing their unread flag.
      {:ok, _} = Conversations.update_conversation_read(actor(recipient), conversation.slug)

      assert {:ok, %Message{} = message} =
               Conversations.create_message(actor(recipient), conversation.slug, %{
                 "body" => "a reply from the recipient"
               })

      assert message.body == "a reply from the recipient"
      assert message.conversation.message_count == 2

      # Posting a message marks both sides unread again.
      reloaded = Repo.reload!(conversation)
      refute reloaded.to_read
      refute reloaded.from_read
    end

    test "a blank body returns the actual message changeset and conversation" do
      sender = confirmed_user_fixture()
      recipient = confirmed_user_fixture()
      conversation = conversation_fixture(sender, recipient)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Conversations.create_message(actor(recipient), conversation.slug, %{"body" => ""})

      assert changeset.data.conversation_id == conversation.id
      refute changeset.valid?
    end

    test "a non-participant regular user is unauthorized" do
      conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

      assert Conversations.create_message(actor(confirmed_user_fixture()), conversation.slug, %{
               "body" => "intruding"
             }) == {:error, :unauthorized}
    end

    test "a banned participant is rejected before any loading" do
      sender = confirmed_user_fixture()
      recipient = confirmed_user_fixture()
      conversation = conversation_fixture(sender, recipient)
      actor = actor(recipient, ban: @ban)

      assert Conversations.create_message(actor, conversation.slug, %{"body" => "hi"}) ==
               {:error, :ban}
    end

    test "a participant with no fingerprint is unauthorized" do
      sender = confirmed_user_fixture()
      recipient = confirmed_user_fixture()
      conversation = conversation_fixture(sender, recipient)
      actor = actor(recipient, fingerprint: nil)

      assert Conversations.create_message(actor, conversation.slug, %{"body" => "hi"}) ==
               {:error, :unauthorized}
    end

    test "an unknown slug is always not found" do
      for viewer <- [confirmed_user_fixture(), admin_user_fixture()] do
        assert Conversations.create_message(actor(viewer), "no-such-slug", %{
                 "body" => "hi"
               }) == {:error, :not_found}
      end
    end
  end

  describe "create_message_approve/3" do
    test "a missing route conversation is not found before the message lookup" do
      assert Conversations.create_message_approve(
               actor(moderator_user_fixture()),
               "missing-conversation",
               "1"
             ) == {:error, :not_found}
    end

    test "a moderator approves a withheld message and a moderation log is written" do
      sender = confirmed_user_fixture()
      recipient = confirmed_user_fixture()
      {conversation, message} = unapproved_message(sender, recipient)
      moderator = moderator_user_fixture()
      report = Repo.get_by!(Report, conversation_id: conversation.id)
      assert report.open

      assert {:ok, %Message{} = approved} =
               Conversations.create_message_approve(
                 actor(moderator),
                 conversation.slug,
                 "#{message.id}"
               )

      assert approved.id == message.id
      assert Repo.reload!(message).approved
      refute Repo.reload!(report).open

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "Conversation.Message.Approve:create"
      assert log.subject_path == "/"
      assert log.body == "Approved private message in conversation ##{conversation.id}"
    end

    test "an admin approves a withheld message" do
      sender = confirmed_user_fixture()
      recipient = confirmed_user_fixture()
      {conversation, message} = unapproved_message(sender, recipient)

      assert {:ok, %Message{}} =
               Conversations.create_message_approve(
                 actor(admin_user_fixture()),
                 conversation.slug,
                 "#{message.id}"
               )

      assert Repo.reload!(message).approved
    end

    test "a non-integer message id is not-found" do
      conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

      assert Conversations.create_message_approve(
               actor(moderator_user_fixture()),
               conversation.slug,
               "not-a-number"
             ) ==
               {:error, :not_found}
    end

    test "missing and wrong-conversation message IDs are always not found" do
      conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())
      other = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())
      other_message = message_fixture(other, other.from)

      for staff <- [moderator_user_fixture(), admin_user_fixture()],
          id <- ["999999999", "#{other_message.id}"] do
        assert Conversations.create_message_approve(actor(staff), conversation.slug, id) ==
                 {:error, :not_found}
      end
    end
  end
end
