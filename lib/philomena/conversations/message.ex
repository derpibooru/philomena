defmodule Philomena.Conversations.Message do
  use Ecto.Schema
  import Ecto.Changeset
  import Philomena.MarkdownWriter

  alias Philomena.Conversations.Conversation
  alias Philomena.Users.User

  schema "messages" do
    belongs_to :conversation, Conversation
    belongs_to :from, User

    field :body, :string
    field :body_md, :string

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [])
    |> validate_required([])
  end

  @doc false
  def creation_changeset(message, attrs, user) do
    message
    |> cast(attrs, [:body])
    |> validate_required([:body])
    |> put_assoc(:from, user)
    |> validate_length(:body, max: 300_000, count: :bytes)
    |> put_markdown(attrs, :body, :body_md)
  end
end
