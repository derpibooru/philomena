defmodule Philomena.Commissions.Commission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "commissions" do
    belongs_to :user, Philomena.Users.User
    belongs_to :sheet_image, Philomena.Images.Image

    field :open, :boolean
    field :categories, {:array, :string}, default: []
    field :information, :string
    field :contact, :string
    field :will_create, :string
    field :will_not_create, :string
    field :commission_items_count, :integer, default: 0

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(commission, attrs) do
    commission
    |> cast(attrs, [])
    |> validate_required([])
  end
end
