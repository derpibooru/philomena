defmodule Philomena.Polls.Poll do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Topics.Topic
  alias Philomena.Users.User
  alias Philomena.PollOptions.PollOption
  alias Philomena.Schema.Time

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
    field :until, :string, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(poll, attrs) do
    poll
    |> cast(attrs, [])
    |> validate_required([])
    |> Time.propagate_time(:active_until, :until)
  end

  @doc false
  def update_changeset(poll, attrs) do
    poll
    |> cast(attrs, [:title, :until, :vote_method])
    |> Time.assign_time(:until, :active_until)
    |> validate_required([:title, :active_until, :vote_method])
    |> validate_length(:title, max: 140, count: :bytes)
    |> validate_inclusion(:vote_method, ["single", "multiple"])
    |> cast_assoc(:options, with: &PollOption.creation_changeset/2)
    |> validate_length(:options, min: 2, max: 20)
    |> ignore_if_blank()
  end

  defp ignore_if_blank(%{valid?: false, changes: changes} = changeset) when changes == %{},
    do: %{changeset | action: :ignore}

  defp ignore_if_blank(changeset),
    do: changeset
end
