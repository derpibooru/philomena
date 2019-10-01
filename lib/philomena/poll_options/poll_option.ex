defmodule Philomena.PollOptions.PollOption do
  use Ecto.Schema
  import Ecto.Changeset

  schema "poll_options" do
    belongs_to :poll, Philomena.Polls.Poll

    field :label, :string
    field :vote_count, :integer, default: 0
  end

  @doc false
  def changeset(poll_option, attrs) do
    poll_option
    |> cast(attrs, [])
    |> validate_required([])
  end
end
