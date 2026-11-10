defmodule Philomena.Conversations do
  @moduledoc """
  Conversation listing, creation, reading, replies, and message approval.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Multi
  alias Philomena.Attribution.Actor
  alias Philomena.Conversations.Conversation
  alias Philomena.Conversations.ConversationIndex
  alias Philomena.Conversations.ConversationPage
  alias Philomena.Conversations.QueryBuilder
  alias Philomena.Conversations.QueryForm
  alias Philomena.Conversations.Message
  alias Philomena.IntegerId
  alias Philomena.Loader
  alias Philomena.ModerationLogs
  alias Philomena.RateLimiter
  alias Philomena.Repo
  alias Philomena.Reports
  alias Philomena.Schema.Approval
  alias Philomena.Users

  @conversation_create_window 60

  @doc """
  Returns whether the actor may send image embeds without approval review.
  """
  @spec trusted_sender?(Actor.t()) :: boolean()
  def trusted_sender?(%Actor{user: user}), do: Approval.trusted?(user)

  defp load_conversation(%Actor{} = actor, slug, action, preloads \\ []) do
    Conversation
    |> where(slug: ^slug)
    |> preload(^preloads)
    |> Loader.one_and_authorize(actor, action)
  end

  defp load_conversation_message(
         %Actor{} = actor,
         %Conversation{} = conversation,
         message_id,
         action
       ) do
    Message
    |> where(conversation_id: ^conversation.id)
    |> preload(:conversation)
    |> Loader.fetch_and_authorize(actor, action, message_id)
  end

  defp put_approval_report(%Multi{} = multi, message_callback)
       when is_function(message_callback, 1) do
    Multi.merge(multi, fn %{conversation: conversation} = changes ->
      message = message_callback.(changes)

      if message.became_unapproved? do
        Reports.put_create_system_report(
          Multi.new(),
          "Approval",
          "PM contains externally-embedded images",
          :conversation_id,
          conversation.id
        )
      else
        Multi.new()
      end
    end)
  end

  @doc """
  Loads the signed-in actor's paginated conversation index.

  The optional `"with"` filter is parsed as a user ID.
  Invalid filters return an blank page and a rejected changeset.

  ## Examples

      iex> list_conversations(actor, %{}, page: 1, page_size: 25)
      {:ok, %ConversationIndex{}}

  """
  @spec list_conversations(Actor.t(), term(), Repo.pagination_params()) ::
          {:ok, ConversationIndex.t()} | {:error, :unauthorized}
  def list_conversations(%Actor{user: user} = actor, params, pagination) do
    with :ok <- authorize(actor, :index, Conversation) do
      {conversations, changeset} =
        params
        |> QueryBuilder.search_conversations(user)
        |> case do
          {:ok, query, query_form} ->
            {Repo.paginate(query, pagination), QueryForm.changeset(query_form)}

          {:error, changeset} ->
            {nil, changeset}
        end

      {:ok, %ConversationIndex{conversations: conversations, changeset: changeset}}
    end
  end

  @doc """
  Returns the authenticated actor's unread, non-hidden conversation count.

  ## Examples

      iex> unread_conversation_count(actor)
      {:ok, 3}

  """
  @spec unread_conversation_count(Actor.t()) ::
          {:ok, non_neg_integer()} | {:error, :unauthorized}
  def unread_conversation_count(%Actor{user: user} = actor) do
    with :ok <- authorize(actor, :index, Conversation) do
      count =
        Conversation
        |> where(
          [conversation],
          ((conversation.to_id == ^user.id and not conversation.to_read) or
             (conversation.from_id == ^user.id and not conversation.from_read)) and
            not ((conversation.to_id == ^user.id and conversation.to_hidden) or
                   (conversation.from_id == ^user.id and conversation.from_hidden))
        )
        |> Repo.aggregate(:count)

      {:ok, count}
    end
  end

  @doc """
  Loads one visible conversation page for `actor`.

  Missing slugs are not found for every actor. Participants and authorized
  staff may view the page. A participant's own read flag is set idempotently;
  staff viewing a conversation do not mutate either participant's state.

  ## Examples

      iex> show_conversation(actor, "slug", page_size: 25)
      {:ok, %ConversationPage{}}

  """
  @spec show_conversation(Actor.t(), String.t(), Repo.pagination_params()) ::
          {:ok, ConversationPage.t()} | {:error, :unauthorized | :not_found}
  def show_conversation(%Actor{user: user} = actor, slug, pagination) do
    with {:ok, conversation} <- load_conversation(actor, slug, :show, [:to, :from]) do
      {:ok, _conversation} =
        conversation
        |> Conversation.read_changeset(user, true)
        |> Repo.update()

      direction = if user.settings.messages_newest_first, do: :desc, else: :asc

      messages =
        Message
        |> where(conversation_id: ^conversation.id)
        |> order_by([{^direction, :created_at}, {^direction, :id}])
        |> preload(:from)
        |> Repo.paginate(pagination)

      {:ok,
       %ConversationPage{
         conversation: conversation,
         messages: messages,
         changeset: Message.changeset(%Message{})
       }}
    end
  end

  @doc """
  Loads a visible conversation as a report target.

  This shares the canonical load-before-authorize slug contract used by the
  conversation page.
  """
  @spec load_report_target(Actor.t(), String.t()) ::
          {:ok, Conversation.t()} | {:error, :unauthorized | :not_found}
  def load_report_target(%Actor{} = actor, slug) do
    load_conversation(actor, slug, :show, [:from, :to])
  end

  @doc """
  Builds a new-conversation form for `actor`.

  New and create apply the same ban and class-ability prerequisites; only
  create requires a fingerprint.
  Non-string recipient input is normalized to an empty recipient.

  ## Examples

      iex> new_conversation(actor, "Recipient")
      {:ok, %Ecto.Changeset{}}

  """
  @spec new_conversation(Actor.t(), term()) ::
          {:ok, Ecto.Changeset.t()} | {:error, :ban | :unauthorized}
  def new_conversation(%Actor{} = actor, params) do
    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :new, Conversation) do
      conversation = %Conversation{messages: [%Message{}]}

      {:ok, Conversation.changeset(conversation, params)}
    end
  end

  @doc """
  Creates a conversation and its single initial message for `actor`.

  Active recipients resolve through Users. Missing or deactivated recipients produce
  a changeset validation error. Successful writes are rate-counted after commit. An
  unapproved first message creates a system report.

  ## Examples

      iex> create_conversation(actor, attrs)
      {:ok, %Conversation{}}

      iex> create_conversation(actor, invalid_attrs)
      {:error, %Ecto.Changeset{}}

  """
  @spec create_conversation(Actor.t(), term()) ::
          {:ok, Conversation.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :rate_limited}
  def create_conversation(%Actor{user: user} = actor, params) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, Conversation),
         {:ok, recipient_name} <- Conversation.recipient_name(params) do
      recipient =
        case Users.load_active_user_by_name(actor, recipient_name) do
          {:ok, user} -> user
          _ -> nil
        end

      conversation_changeset =
        Conversation.creation_changeset(%Conversation{}, user, recipient, params)

      Multi.new()
      |> Multi.reserve_action(
        fn ->
          RateLimiter.record_action(actor, :conversation_create, @conversation_create_window)
        end,
        fn -> RateLimiter.rollback_action(actor, :conversation_create) end
      )
      |> Multi.insert(:conversation, conversation_changeset)
      |> put_approval_report(fn %{conversation: %{messages: [message]}} -> message end)
      |> Multi.transact()
      |> case do
        {:ok, %{conversation: %Conversation{} = conversation}} ->
          {:ok, conversation}

        {:error, :action_reservation, :rate_limited, _changes} ->
          {:error, :rate_limited}

        {:error, :conversation, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Marks `actor`'s participant side of the conversation read or unread.

  The operation is idempotent. Authorized staff may view the conversation but,
  because they are not a participant, do not change either participant flag.
  Missing slugs are always not found.
  """
  @spec update_conversation_read(Actor.t(), String.t(), boolean()) ::
          {:ok, Conversation.t()} | {:error, :unauthorized | :not_found | Ecto.Changeset.t()}
  def update_conversation_read(%Actor{user: user} = actor, slug, read \\ true) do
    with {:ok, conversation} <- load_conversation(actor, slug, :show) do
      conversation
      |> Conversation.read_changeset(user, read)
      |> Repo.update()
    end
  end

  @doc """
  Marks `actor`'s participant side of the conversation hidden or restored.

  The operation is idempotent. Authorized staff may view the conversation, but
  do not change either participant flag. Missing slugs are always not found.
  """
  @spec update_conversation_hide(Actor.t(), String.t(), boolean()) ::
          {:ok, Conversation.t()} | {:error, :unauthorized | :not_found | Ecto.Changeset.t()}
  def update_conversation_hide(%Actor{user: user} = actor, slug, hidden \\ true) do
    with {:ok, conversation} <- load_conversation(actor, slug, :show) do
      conversation
      |> Conversation.hidden_changeset(user, hidden)
      |> Repo.update()
    end
  end

  @doc """
  Posts a reply to a visible conversation.

  Write access is checked before loading. Participant and staff reply policy is
  represented by the `:reply` ability. Validation failures return a rejected
  changeset. Success returns the message and total count needed for the redirect
  page.

  ## Examples

      iex> create_message(actor, "slug", %{"body" => "hello"})
      {:ok, %Message{}}

      iex> create_message(actor, "slug", %{"body" => ""})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_message(Actor.t(), String.t(), term()) ::
          {:ok, Message.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, :ban | :unauthorized | :not_found | Ecto.Changeset.t()}
  def create_message(%Actor{user: user} = actor, slug, params) do
    with :ok <- verify_write_access(actor),
         {:ok, conversation} <- load_conversation(actor, slug, :reply) do
      message_count_query =
        from message in Message,
          where: message.conversation_id == ^conversation.id,
          select: count(message.id)

      message_changeset =
        conversation
        |> Ecto.build_assoc(:messages)
        |> Message.creation_changeset(params, user)

      conversation_changeset = Conversation.new_message_changeset(conversation)

      Multi.new()
      |> Multi.insert(:message, message_changeset)
      |> Multi.update(:conversation, conversation_changeset)
      |> Multi.one(:message_count, message_count_query)
      |> put_approval_report(fn %{message: message} -> message end)
      |> Multi.transact()
      |> case do
        {:ok,
         %{
           conversation: %Conversation{} = conversation,
           message: %Message{} = message,
           message_count: message_count
         }} ->
          conversation = %{conversation | message_count: message_count}
          message = %{message | conversation: conversation}

          {:ok, message}

        {:error, :message, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Approves one message scoped to the conversation named by `conversation_slug`.

  The route conversation loads before the nested message query. Malformed,
  absent, and wrong-conversation message IDs are therefore all not found.
  Approval, participant unread flags, report closure, and the moderation log
  commit atomically. Affected reports are reindexed after commit.

  ## Examples

      iex> create_message_approve(actor, "conversation-slug", "1")
      {:ok, %Message{}}

  """
  @spec create_message_approve(Actor.t(), String.t(), IntegerId.integer_id()) ::
          {:ok, Message.t()}
          | {:error, :unauthorized | :not_found | Ecto.Changeset.t()}
  def create_message_approve(%Actor{} = actor, conversation_slug, message_id) do
    with {:ok, conversation} <- load_conversation(actor, conversation_slug, :show),
         {:ok, message} <- load_conversation_message(actor, conversation, message_id, :approve) do
      conversation_update_query =
        from conversation in Conversation,
          where: conversation.id == ^message.conversation_id,
          update: [set: [from_read: false, to_read: false]]

      Multi.new()
      |> Multi.update(:message, Message.approve_changeset(message))
      |> Multi.update_all(:conversation, conversation_update_query, [])
      |> Reports.put_close_reports(
        :reports,
        actor.user,
        conversation_id: message.conversation_id
      )
      |> ModerationLogs.put_log(
        :moderation_log,
        actor,
        "Conversation.Message.Approve:create",
        "/",
        "Approved private message in conversation ##{message.conversation_id}"
      )
      |> Multi.transact()
      |> case do
        {:ok, %{message: %Message{} = message}} ->
          {:ok, message}

        {:error, :message, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}
      end
    end
  end
end
