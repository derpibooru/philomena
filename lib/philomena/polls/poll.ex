defmodule Philomena.Polls.Poll do
  use Ecto.Schema
  import Ecto.Changeset

  schema "polls" do
    belongs_to :topic, Philomena.Topics.Topic
    belongs_to :deleted_by, Philomena.Users.User

    field :title, :string
    field :vote_method, :string
    field :active_until, :naive_datetime
    field :total_votes, :integer, default: 0
    field :hidden_from_users, :boolean, default: false
    field :deletion_reason, :string, default: ""

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(poll, attrs) do
    poll
    |> cast(attrs, [])
    |> validate_required([])
  end
end
