defmodule Philomena.Bans.Fingerprint do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  import Philomena.Schema.Time
  import Philomena.Schema.BanId

  schema "fingerprint_bans" do
    belongs_to :banning_user, User

    field :reason, :string
    field :note, :string
    field :enabled, :boolean, default: true
    field :valid_until, :utc_datetime
    field :fingerprint, :string
    field :generated_ban_id, :string

    field :until, :string, virtual: true

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(fingerprint_ban, attrs) do
    fingerprint_ban
    |> cast(attrs, [])
    |> propagate_time(:valid_until, :until)
  end

  def save_changeset(fingerprint_ban, attrs) do
    fingerprint_ban
    |> cast(attrs, [:reason, :note, :enabled, :fingerprint, :until])
    |> assign_time(:until, :valid_until)
    |> put_ban_id("F")
    |> validate_required([:reason, :enabled, :fingerprint, :valid_until])
  end
end
