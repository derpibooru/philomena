defmodule Philomena.Conversations.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Reports.Report
  alias Philomena.Conversations.Message

  @derive {Phoenix.Param, key: :slug}

  @type t :: %__MODULE__{}

  schema "conversations" do
    belongs_to :from, User
    belongs_to :to, User
    has_many :messages, Message
    has_many :reports, Report

    field :title, :string
    field :to_read, :boolean, default: false
    field :from_read, :boolean, default: true
    field :to_hidden, :boolean, default: false
    field :from_hidden, :boolean, default: false
    field :slug, :string
    field :last_message_at, :utc_datetime

    field :message_count, :integer, virtual: true
    field :recipient, :string, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(conversation, attrs \\ %{}) do
    cast(conversation, attrs, [:recipient])
  end

  @doc false
  def recipient_name(attrs) do
    with {:ok, conversation} <-
           %__MODULE__{}
           |> cast(attrs, [:recipient])
           |> validate_required([:recipient])
           |> apply_action(:create) do
      {:ok, conversation.recipient}
    end
  end

  @doc false
  def creation_changeset(conversation, from, to, attrs) do
    conversation
    |> cast(attrs, [:title, :recipient])
    |> put_assoc(:from, from)
    |> put_assoc(:to, to)
    |> put_change(:slug, Ecto.UUID.generate())
    |> cast_assoc(:messages, with: &Message.creation_changeset(&1, &2, from))
    |> set_last_message()
    |> validate_length(:messages, is: 1)
    |> validate_length(:title, max: 300, count: :bytes)
    |> validate_required([:title, :from, :to])
  end

  @doc false
  def read_changeset(conversation, user, desired_state) do
    conversation
    |> change()
    |> put_conditional(conversation.from_id == user.id, :from_read, desired_state)
    |> put_conditional(conversation.to_id == user.id, :to_read, desired_state)
  end

  @doc false
  def hidden_changeset(conversation, user, desired_state) do
    conversation
    |> change()
    |> put_conditional(conversation.from_id == user.id, :from_hidden, desired_state)
    |> put_conditional(conversation.to_id == user.id, :to_hidden, desired_state)
  end

  @doc false
  def new_message_changeset(conversation) do
    conversation
    |> change(from_read: false)
    |> change(to_read: false)
    |> set_last_message()
  end

  defp set_last_message(changeset) do
    change(changeset, last_message_at: DateTime.utc_now(:second))
  end

  defp put_conditional(changeset, true, key, value), do: put_change(changeset, key, value)
  defp put_conditional(changeset, false, _key, _value), do: changeset
end
