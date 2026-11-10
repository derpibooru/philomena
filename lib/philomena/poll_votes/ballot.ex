defmodule Philomena.PollVotes.Ballot do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Polls.Poll

  @type t :: %__MODULE__{}

  embedded_schema do
    belongs_to :poll, Poll
    field :option_ids, {:array, :integer}
  end

  @doc false
  def changeset(ballot, attrs, poll, valid_option_ids) do
    ballot
    |> cast(attrs, [:option_ids])
    |> validate_required(:option_ids, message: "must select a choice")
    |> validate_change(:option_ids, &validate_selection(poll, valid_option_ids, &1, &2))
  end

  @doc false
  def validate_active(changeset, active?) do
    if active? do
      changeset
    else
      add_error(changeset, :option_ids, "poll is closed")
    end
  end

  @doc false
  def validate_not_voted(changeset, voted?) do
    if voted? do
      add_error(changeset, :option_ids, "has already voted")
    else
      changeset
    end
  end

  defp validate_selection(poll, valid_option_ids, name, option_ids) do
    cond do
      option_ids == [] ->
        []

      not Enum.all?(option_ids, &(&1 in valid_option_ids)) ->
        [{name, "contains an invalid choice"}]

      Enum.uniq(option_ids) != option_ids ->
        [{name, "contains duplicate choices"}]

      poll.vote_method == "single" and Enum.count_until(option_ids, 2) != 1 ->
        [{name, "must select exactly one choice"}]

      poll.vote_method == "multiple" and Enum.count_until(option_ids, 1) != 1 ->
        [{name, "must select at least one choice"}]

      true ->
        []
    end
  end
end
