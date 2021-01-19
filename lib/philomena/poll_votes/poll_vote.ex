defmodule Philomena.PollVotes.PollVote do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.PollOptions.PollOption
  alias Philomena.Users.User

  schema "poll_votes" do
    belongs_to :poll_option, PollOption
    belongs_to :user, User

    field :rank, :integer

    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end

  @doc false
  def changeset(poll_vote, attrs) do
    poll_vote
    |> cast(attrs, [])
    |> validate_required([])
  end
end
