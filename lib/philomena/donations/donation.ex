defmodule Philomena.Donations.Donation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "donations" do
    belongs_to :user, Philomena.Users.User

    field :email, :string
    field :amount, :decimal
    field :fee, :decimal
    field :txn_id, :string
    field :reciept_id, :string
    field :note, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(donation, attrs) do
    donation
    |> cast(attrs, [])
    |> validate_required([])
  end
end
