defmodule Philomena.Conversations do
  @moduledoc """
  The Conversations context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo
  alias Philomena.Conversations.Conversation
  alias Philomena.Conversations.Message
  alias Philomena.Reports
  alias Philomena.Users

  @doc """
  Returns the number of unread conversations for the given user.

  Conversations hidden by the given user are not counted.

  ## Examples

      iex> count_unread_conversations(user1)
      0

      iex> count_unread_conversations(user2)
      7

  """
  def count_unread_conversations(user) do
    Conversation
    |> where(
      [c],
      ((c.to_id == ^user.id and c.to_read == false) or
         (c.from_id == ^user.id and c.from_read == false)) and
        not ((c.to_id == ^user.id and c.to_hidden == true) or
               (c.from_id == ^user.id and c.from_hidden == true))
    )
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns a `m:Scrivener.Page` of conversations between the partner and the user.

  ## Examples

      iex> list_conversations_with("123", %User{}, page_size: 10)
      %Scrivener.Page{}

  """
  def list_conversations_with(partner_id, user, pagination) do
    query =
      from c in Conversation,
        where:
          (c.from_id == ^partner_id and c.to_id == ^user.id) or
            (c.to_id == ^partner_id and c.from_id == ^user.id)

    list_conversations(query, user, pagination)
  end

  @doc """
  Returns a `m:Scrivener.Page` of conversations sent by or received from the user.

  ## Examples

      iex> list_conversations_with("123", %User{}, page_size: 10)
      %Scrivener.Page{}

  """
  def list_conversations(queryable \\ Conversation, user, pagination) do
    query =
      from c in queryable,
        as: :conversations,
        where:
          (c.from_id == ^user.id and not c.from_hidden) or
            (c.to_id == ^user.id and not c.to_hidden),
        inner_lateral_join:
          cnt in subquery(
            from m in Message,
              where: m.conversation_id == parent_as(:conversations).id,
              select: %{count: count()}
          ),
        on: true,
        order_by: [desc: :last_message_at],
        preload: [:to, :from],
        select: %{c | message_count: cnt.count}

    Repo.paginate(query, pagination)
  end

  @doc """
  Creates a conversation.

  ## Examples

      iex> create_conversation(from, to, %{field: value})
      {:ok, %Conversation{}}

      iex> create_conversation(from, to, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_conversation(from, attrs \\ %{}) do
    to = Users.get_user_by_name(attrs["recipient"])

    %Conversation{}
    |> Conversation.creation_changeset(from, to, attrs)
    |> Repo.insert()
    |> case do
      {:ok, conversation} ->
        report_non_approved_message(hd(conversation.messages))
        {:ok, conversation}

      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking conversation changes.

  ## Examples

      iex> change_conversation(conversation)
      %Ecto.Changeset{source: %Conversation{}}

  """
  def change_conversation(%Conversation{} = conversation) do
    Conversation.changeset(conversation, %{})
  end

  @doc """
  Marks a conversation as read or unread from the perspective of the given user.

  ## Examples

      iex> mark_conversation_read(conversation, user, true)
      {:ok, %Conversation{}}

      iex> mark_conversation_read(conversation, user, false)
      {:ok, %Conversation{}}

      iex> mark_conversation_read(conversation, %User{}, true)
      {:error, %Ecto.Changeset{}}

  """
  def mark_conversation_read(%Conversation{} = conversation, user, read \\ true) do
    changes =
      %{}
      |> put_conditional(:to_read, read, conversation.to_id == user.id)
      |> put_conditional(:from_read, read, conversation.from_id == user.id)

    conversation
    |> Conversation.read_changeset(changes)
    |> Repo.update()
  end

  @doc """
  Marks a conversation as hidden or visible from the perspective of the given user.

  Hidden conversations are not shown in the list of conversations for the user, and
  are not counted when retrieving the number of unread conversations.

  ## Examples

      iex> mark_conversation_hidden(conversation, user, true)
      {:ok, %Conversation{}}

      iex> mark_conversation_hidden(conversation, user, false)
      {:ok, %Conversation{}}

      iex> mark_conversation_hidden(conversation, %User{}, true)
      {:error, %Ecto.Changeset{}}

  """
  def mark_conversation_hidden(%Conversation{} = conversation, user, hidden \\ true) do
    changes =
      %{}
      |> put_conditional(:to_hidden, hidden, conversation.to_id == user.id)
      |> put_conditional(:from_hidden, hidden, conversation.from_id == user.id)

    conversation
    |> Conversation.hidden_changeset(changes)
    |> Repo.update()
  end

  defp put_conditional(map, key, value, condition) do
    if condition do
      Map.put(map, key, value)
    else
      map
    end
  end

  @doc """
  Returns the number of messages in the given conversation.

  ## Example

      iex> count_messages(%Conversation{})
      3

  """
  def count_messages(conversation) do
    Message
    |> where(conversation_id: ^conversation.id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns a `m:Scrivener.Page` of 2-tuples of messages and rendered output
  within a conversation.

  Messages are ordered by user message preference (`messages_newest_first`).

  When coerced to a list and rendered as Markdown, the result may look like:

      [
        {%Message{body: "hello *world*"}, "hello <strong>world</strong>"}
      ]

  ## Example

      iex> list_messages(%Conversation{}, %User{}, & &1.body, page_size: 10)
      %Scrivener.Page{}

  """
  def list_messages(conversation, user, collection_renderer, pagination) do
    direction =
      if user.messages_newest_first do
        :desc
      else
        :asc
      end

    query =
      from m in Message,
        where: m.conversation_id == ^conversation.id,
        order_by: [{^direction, :created_at}],
        preload: :from

    messages = Repo.paginate(query, pagination)
    rendered = collection_renderer.(messages)

    put_in(messages.entries, Enum.zip(messages.entries, rendered))
  end

  @doc """
  Creates a message within a conversation.

  ## Examples

      iex> create_message(%Conversation{}, %User{}, %{field: value})
      {:ok, %Message{}}

      iex> create_message(%Conversation{}, %User{}, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_message(conversation, user, attrs \\ %{}) do
    message_changeset =
      conversation
      |> Ecto.build_assoc(:messages)
      |> Message.creation_changeset(attrs, user)

    conversation_changeset =
      Conversation.new_message_changeset(conversation)

    Multi.new()
    |> Multi.insert(:message, message_changeset)
    |> Multi.update(:conversation, conversation_changeset)
    |> Repo.transaction()
    |> case do
      {:ok, %{message: message}} ->
        report_non_approved_message(message)
        {:ok, message}

      _error ->
        {:error, message_changeset}
    end
  end

  @doc """
  Approves a previously-posted message which was not approved at post time.

  ## Examples

      iex> approve_message(%Message{}, %User{})
      {:ok, %Message{}}

      iex> approve_message(%Message{}, %User{})
      {:error, %Ecto.Changeset{}}

  """
  def approve_message(message, approving_user) do
    message_changeset = Message.approve_changeset(message)

    conversation_update_query =
      from c in Conversation,
        where: c.id == ^message.conversation_id,
        update: [set: [from_read: false, to_read: false]]

    reports_query =
      Reports.close_report_query({"Conversation", message.conversation_id}, approving_user)

    Multi.new()
    |> Multi.update(:message, message_changeset)
    |> Multi.update_all(:conversation, conversation_update_query, [])
    |> Multi.update_all(:reports, reports_query, [])
    |> Repo.transaction()
    |> case do
      {:ok, %{reports: {_count, reports}, message: message}} ->
        Reports.reindex_reports(reports)

        message

      _error ->
        {:error, message_changeset}
    end
  end

  @doc """
  Generates a system report for an unapproved message.

  This is called by `create_conversation/2` and `create_message/3`, so it normally does not
  need to be called explicitly.

  ## Examples

      iex> report_non_approved_message(%Message{approved: false})
      {:ok, %Report{}}

      iex> report_non_approved_message(%Message{approved: true})
      {:ok, nil}

  """
  def report_non_approved_message(message) do
    if message.approved do
      {:ok, nil}
    else
      Reports.create_system_report(
        {"Conversation", message.conversation_id},
        "Approval",
        "PM contains externally-embedded images"
      )
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.

  ## Examples

      iex> change_message(message)
      %Ecto.Changeset{source: %Message{}}

  """
  def change_message(%Message{} = message) do
    Message.changeset(message, %{})
  end
end
