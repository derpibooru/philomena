defmodule Philomena.Conversations.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Conversations.Message

  @derive {Phoenix.Param, key: :slug}

  schema "conversations" do
    belongs_to :from, User
    belongs_to :to, User
    has_many :messages, Message

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
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [])
    |> validate_required([])
  end

  @doc false
  def read_changeset(conversation, attrs) do
    cast(conversation, attrs, [:from_read, :to_read])
  end

  @doc false
  def hidden_changeset(conversation, attrs) do
    cast(conversation, attrs, [:from_hidden, :to_hidden])
  end

  @doc false
  def creation_changeset(conversation, from, to, attrs) do
    conversation
    |> cast(attrs, [:title])
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
  def new_message_changeset(conversation) do
    conversation
    |> change(from_read: false)
    |> change(to_read: false)
    |> set_last_message()
  end

  defp set_last_message(changeset) do
    change(changeset, last_message_at: DateTime.utc_now(:second))
  end
end
