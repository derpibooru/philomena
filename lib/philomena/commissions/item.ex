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

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:item_type, :description, :base_price, :add_ons, :example_image_id])
    |> validate_required([:commission_id, :base_price, :item_type, :description])
    |> validate_length(:description, max: 300, count: :bytes)
    |> validate_length(:add_ons, max: 500, count: :bytes)
    |> validate_number(:base_price, greater_than_or_equal_to: 0, less_than_or_equal_to: 99_999)
    |> validate_inclusion(:item_type, Commission.types())
    |> foreign_key_constraint(:example_image_id, name: :fk_rails_56d368749a)
  end
end
