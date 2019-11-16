defmodule Philomena.Conversations.Message do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Conversations.Conversation
  alias Philomena.Users.User

  schema "messages" do
    belongs_to :conversation, Conversation
    belongs_to :from, User

    field :body, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [])
    |> validate_required([])
  end
end
