defmodule Philomena.Bans.Fingerprint do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  schema "fingerprint_bans" do
    belongs_to :banning_user, User

    field :reason, :string
    field :note, :string
    field :enabled, :boolean, default: true
    field :valid_until, :utc_datetime
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
