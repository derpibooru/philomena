defmodule Philomena.PollVotes.PollVote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "poll_votes" do
    belongs_to :poll_option, Philomena.PollOptions.PollOption
    belongs_to :user, Philomena.Users.User

    field :rank, :integer

    timestamps(inserted_at: :created_at, updated_at: false)
  end

  @doc false
  def changeset(poll_vote, attrs) do
    poll_vote
    |> cast(attrs, [])
    |> validate_required([])
  end
end
