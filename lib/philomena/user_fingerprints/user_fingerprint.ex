defmodule Philomena.UserFingerprints.UserFingerprint do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  @type t :: %__MODULE__{}

  schema "user_fingerprints" do
    belongs_to :user, User

    field :fingerprint, :string
    field :uses, :integer, default: 1

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def insert_fields do
    [:user_id, :fingerprint, :uses]
  end

  @doc false
  def changeset(user_fingerprint, attrs \\ %{}) do
    user_fingerprint
    |> cast(attrs, [:fingerprint])
    |> validate_required([:fingerprint])
  end
end
