defmodule Philomena.Bans.Fingerprint do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Schema.BanId

  schema "fingerprint_bans" do
    belongs_to :banning_user, User

    field :reason, :string
    field :note, :string
    field :enabled, :boolean, default: true
    field :valid_until, PhilomenaQuery.Ecto.RelativeDate
    field :fingerprint, :string
    field :generated_ban_id, :string

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(fingerprint_ban, attrs) do
    fingerprint_ban
    |> cast(attrs, [:reason, :note, :enabled, :fingerprint, :valid_until])
    |> BanId.put_ban_id("F")
    |> validate_required([:reason, :enabled, :fingerprint, :valid_until])
    |> check_constraint(:valid_until, name: :fingerprint_ban_duration_must_be_valid)
  end
end
