defmodule Philomena.Conversations do
  @moduledoc """
  The Conversations context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Conversations.Conversation

  @doc """
  Gets a single conversation.

  Raises `Ecto.NoResultsError` if the Conversation does not exist.

  ## Examples

      iex> get_conversation!(123)
      %Conversation{}

      iex> get_conversation!(456)
      ** (Ecto.NoResultsError)

  """
  def get_conversation!(id), do: Repo.get!(Conversation, id)

  @doc """
  Creates a conversation.

  ## Examples

      iex> create_conversation(%{field: value})
      {:ok, %Conversation{}}

      iex> create_conversation(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_conversation(from, attrs \\ %{}) do
    %Conversation{}
    |> Conversation.creation_changeset(from, attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a conversation.

  ## Examples

      iex> update_conversation(conversation, %{field: new_value})
      {:ok, %Conversation{}}

      iex> update_conversation(conversation, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_conversation(%Conversation{} = conversation, attrs) do
    conversation
    |> Conversation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Conversation.

  ## Examples

      iex> delete_conversation(conversation)
      {:ok, %Conversation{}}

      iex> delete_conversation(conversation)
      {:error, %Ecto.Changeset{}}

  """
  def delete_conversation(%Conversation{} = conversation) do
    Repo.delete(conversation)
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

  def count_unread_conversations(user) do
    Conversation
    |> where(
      [c],
      ((c.to_id == ^user.id and c.to_read == false) or
         (c.from_id == ^user.id and c.from_read == false)) and
        not ((c.to_id == ^user.id and c.to_hidden == true) or
               (c.from_id == ^user.id and c.from_hidden == true))
    )
    |> Repo.aggregate(:count, :id)
  end

  def mark_conversation_read(conversation, user, read \\ true)

  def mark_conversation_read(
        %Conversation{to_id: user_id, from_id: user_id} = conversation,
        %{id: user_id},
        read
      ) do
    conversation
    |> Conversation.read_changeset(%{to_read: read, from_read: read})
    |> Repo.update()
  end

  def mark_conversation_read(%Conversation{to_id: user_id} = conversation, %{id: user_id}, read) do
    conversation
    |> Conversation.read_changeset(%{to_read: read})
    |> Repo.update()
  end

  def mark_conversation_read(%Conversation{from_id: user_id} = conversation, %{id: user_id}, read) do
    conversation
    |> Conversation.read_changeset(%{from_read: read})
    |> Repo.update()
  end

  def mark_conversation_read(_conversation, _user, _read), do: {:ok, nil}

  def mark_conversation_hidden(conversation, user, hidden \\ true)

  def mark_conversation_hidden(
        %Conversation{to_id: user_id} = conversation,
        %{id: user_id},
        hidden
      ) do
    conversation
    |> Conversation.hidden_changeset(%{to_hidden: hidden})
    |> Repo.update()
  end

  def mark_conversation_hidden(
        %Conversation{from_id: user_id} = conversation,
        %{id: user_id},
        hidden
      ) do
    conversation
    |> Conversation.hidden_changeset(%{from_hidden: hidden})
    |> Repo.update()
  end

  def mark_conversation_hidden(_conversation, _user, _read), do: {:ok, nil}

  alias Philomena.Conversations.Message

  @doc """
  Gets a single message.

  Raises `Ecto.NoResultsError` if the Message does not exist.

  ## Examples

      iex> get_message!(123)
      %Message{}

      iex> get_message!(456)
      ** (Ecto.NoResultsError)

  """
  def get_message!(id), do: Repo.get!(Message, id)

  @doc """
  Creates a message.

  ## Examples

      iex> create_message(%{field: value})
      {:ok, %Message{}}

      iex> create_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_message(conversation, user, attrs \\ %{}) do
    message =
      Ecto.build_assoc(conversation, :messages)
      |> Message.creation_changeset(attrs, user)

    conversation_query =
      Conversation
      |> where(id: ^conversation.id)

    now = DateTime.utc_now()

    Multi.new()
    |> Multi.insert(:message, message)
    |> Multi.update_all(:conversation, conversation_query,
      set: [from_read: false, to_read: false, last_message_at: now]
    )
    |> Repo.transaction()
  end

  @doc """
  Updates a message.

  ## Examples

      iex> update_message(message, %{field: new_value})
      {:ok, %Message{}}

      iex> update_message(message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Message.

  ## Examples

      iex> delete_message(message)
      {:ok, %Message{}}

      iex> delete_message(message)
      {:error, %Ecto.Changeset{}}

  """
  def delete_message(%Message{} = message) do
    Repo.delete(message)
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
