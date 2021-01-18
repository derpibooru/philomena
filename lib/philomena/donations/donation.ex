defmodule Philomena.Donations.Donation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  schema "donations" do
    belongs_to :user, User

    field :email, :string
    field :amount, :decimal
    field :fee, :decimal
    field :txn_id, :string
    field :receipt_id, :string
    field :note, :string

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(donation, attrs) do
    donation
    |> cast(attrs, [:email, :amount, :note, :user_id])
    |> validate_required([])
    |> foreign_key_constraint(:user_id, name: :fk_rails_5470822a00)
  end
end
