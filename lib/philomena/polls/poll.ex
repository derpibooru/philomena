defmodule Philomena.Polls.Poll do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Topics.Topic
  alias Philomena.Users.User
  alias Philomena.PollOptions.PollOption

  schema "polls" do
    belongs_to :topic, Topic
    belongs_to :deleted_by, User
    has_many :options, PollOption

    field :title, :string
    field :vote_method, :string
    field :active_until, :utc_datetime
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
