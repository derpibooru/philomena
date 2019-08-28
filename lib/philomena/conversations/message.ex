defmodule Philomena.Conversations.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    belongs_to :conversation, Philomena.Conversations.Conversation
    belongs_to :from, Philomena.Users.User

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
