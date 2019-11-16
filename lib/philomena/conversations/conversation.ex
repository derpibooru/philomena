defmodule Philomena.Conversations.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  @derive {Phoenix.Param, key: :slug}

  schema "conversations" do
    belongs_to :from, User
    belongs_to :to, User

    field :title, :string
    field :to_read, :boolean, default: false
    field :from_read, :boolean, default: true
    field :to_hidden, :boolean, default: false
    field :from_hidden, :boolean, default: false
    field :slug, :string
    field :last_message_at, :naive_datetime

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [])
    |> validate_required([])
  end
end
