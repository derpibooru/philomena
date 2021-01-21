defmodule Philomena.Bans.Fingerprint do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Schema.Time
  alias Philomena.Schema.BanId

  schema "fingerprint_bans" do
    belongs_to :banning_user, User

    field :reason, :string
    field :note, :string
    field :enabled, :boolean, default: true
    field :valid_until, :utc_datetime
    field :fingerprint, :string
    field :generated_ban_id, :string

    field :until, :string, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(fingerprint_ban, attrs) do
    fingerprint_ban
    |> cast(attrs, [])
    |> Time.propagate_time(:valid_until, :until)
  end

  def save_changeset(fingerprint_ban, attrs) do
    fingerprint_ban
    |> cast(attrs, [:reason, :note, :enabled, :fingerprint, :until])
    |> Time.assign_time(:until, :valid_until)
    |> BanId.put_ban_id("F")
    |> validate_required([:reason, :enabled, :fingerprint, :valid_until])
    |> check_constraint(:valid_until, name: :fingerprint_ban_duration_must_be_valid)
  end
end
