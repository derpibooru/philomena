defmodule Philomena.Conversations.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Conversations.Message
  alias Philomena.Repo

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
    field :recipient, :string, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [])
    |> validate_required([])
  end

  def read_changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:from_read, :to_read])
  end

  def hidden_changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:from_hidden, :to_hidden])
  end

  @doc false
  def creation_changeset(conversation, from, attrs) do
    conversation
    |> cast(attrs, [:title, :recipient])
    |> validate_required([:title, :recipient])
    |> validate_length(:title, max: 300, count: :bytes)
    |> put_assoc(:from, from)
    |> put_recipient()
    |> set_slug()
    |> set_last_message()
    |> cast_assoc(:messages, with: {Message, :creation_changeset, [from]})
    |> validate_length(:messages, is: 1)
  end

  defp set_slug(changeset) do
    changeset
    |> change(slug: Ecto.UUID.generate())
  end

  defp set_last_message(changeset) do
    changeset
    |> change(last_message_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp put_recipient(changeset) do
    recipient = changeset |> get_field(:recipient)
    user = Repo.get_by(User, name: recipient)

    changeset
    |> put_change(:to, user)
    |> validate_required(:to)
  end
end
