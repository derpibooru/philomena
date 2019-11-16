defmodule Philomena.Commissions.Item do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Commissions.Commission
  alias Philomena.Images.Image

  schema "commission_items" do
    belongs_to :commission, Commission
    belongs_to :example_image, Image

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
