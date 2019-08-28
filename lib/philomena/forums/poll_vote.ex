defmodule Philomena.Forums.PollVote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "poll_votes" do
    timestamps()
  end

  @doc false
  def changeset(poll_vote, attrs) do
    poll_vote
    |> cast(attrs, [])
    |> validate_required([])
  end
end
