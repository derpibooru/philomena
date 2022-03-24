defmodule Philomena.Conversations.Message do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Conversations.Conversation
  alias Philomena.Users.User
  alias Philomena.Schema.Approval

  schema "messages" do
    belongs_to :conversation, Conversation
    belongs_to :from, User

    field :body, :string
    field :approved, :boolean, default: false

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
    |> Approval.maybe_put_approval(user)
  end

  def approve_changeset(message) do
    change(message, approved: true)
  end
end
