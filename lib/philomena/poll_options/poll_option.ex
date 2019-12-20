defmodule Philomena.PollOptions.PollOption do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.PollVotes.PollVote
  alias Philomena.Polls.Poll

  schema "poll_options" do
    belongs_to :poll, Poll
    has_many :poll_votes, PollVote

    field :label, :string
    field :vote_count, :integer, default: 0
  end

  @doc false
  def changeset(poll_option, attrs) do
    poll_option
    |> cast(attrs, [])
    |> validate_required([])
  end

  @doc false
  def creation_changeset(poll_option, attrs) do
    poll_option
    |> cast(attrs, [:label])
    |> validate_required([:label])
    |> validate_length(:label, max: 80, count: :bytes)
    |> unique_constraint(:label, name: :index_poll_options_on_poll_id_and_label)
    |> ignore_if_blank()
  end

  defp ignore_if_blank(%{valid?: false, changes: changes} = changeset) when changes == %{},
    do: %{changeset | action: :ignore}
  defp ignore_if_blank(changeset),
    do: changeset
end
