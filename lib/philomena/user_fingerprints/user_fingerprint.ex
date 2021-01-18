defmodule Philomena.UserFingerprints.UserFingerprint do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  schema "user_fingerprints" do
    belongs_to :user, User

    field :fingerprint, :string
    field :uses, :integer, default: 0

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(user_fingerprint, attrs) do
    user_fingerprint
    |> cast(attrs, [])
    |> validate_required([])
  end
end
