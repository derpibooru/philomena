defmodule Philomena.Bans.Fingerprint do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fingerprint_bans" do
    belongs_to :banning_user, Philomena.Users.User

    field :reason, :string
    field :note, :string
    field :enabled, :boolean, default: true
    field :valid_until, :naive_datetime
    field :fingerprint, :string
    field :generated_ban_id, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(fingerprint, attrs) do
    fingerprint
    |> cast(attrs, [])
    |> validate_required([])
  end
end
