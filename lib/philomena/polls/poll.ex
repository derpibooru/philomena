defmodule Philomena.Polls.Poll do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Topics.Topic
  alias Philomena.PollOptions.PollOption

  @type t :: %__MODULE__{}

  schema "polls" do
    belongs_to :topic, Topic
    has_many :options, PollOption, on_replace: :delete

    field :title, :string
    field :vote_method, :string
    field :active_until, PhilomenaQuery.Ecto.RelativeDate
    field :total_votes, :integer, default: 0

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(poll, attrs \\ %{}) do
    poll
    |> cast(attrs, [:title, :active_until, :vote_method])
    |> validate_required([:title, :active_until, :vote_method])
    |> validate_length(:title, max: 140, count: :bytes)
    |> validate_inclusion(:vote_method, ["single", "multiple"])
    |> cast_assoc(:options, required: true, with: &PollOption.creation_changeset/2)
    |> validate_length(:options, min: 2, max: 20)
    |> preserve_recorded_vote_meaning(poll)
    |> ignore_if_blank()
  end

  defp preserve_recorded_vote_meaning(changeset, %__MODULE__{total_votes: total_votes})
       when total_votes > 0 do
    changeset
    |> reject_vote_method_change()
    |> reject_option_changes()
  end

  defp preserve_recorded_vote_meaning(changeset, _poll), do: changeset

  defp reject_vote_method_change(changeset) do
    if get_change(changeset, :vote_method) do
      add_error(changeset, :vote_method, "cannot be changed after voting has started")
    else
      changeset
    end
  end

  defp reject_option_changes(changeset) do
    changed? =
      changeset
      |> get_change(:options, [])
      |> Enum.any?(fn option_changeset ->
        option_changeset.action in [:insert, :delete, :replace] or option_changeset.changes != %{}
      end)

    if changed? do
      add_error(changeset, :options, "cannot be changed after voting has started")
    else
      changeset
    end
  end

  defp ignore_if_blank(%{valid?: false, changes: changes} = changeset) when changes == %{},
    do: %{changeset | action: :ignore}

  defp ignore_if_blank(changeset),
    do: changeset
end
