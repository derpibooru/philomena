defmodule Philomena.Commissions.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "commission_items" do
    belongs_to :commission, Philomena.Commissions.Commission
    belongs_to :example_image, Philomena.Images.Image

    field :item_type, :string
    field :description, :string
    field :base_price, :decimal
    field :add_ons, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [])
    |> validate_required([])
  end
end
