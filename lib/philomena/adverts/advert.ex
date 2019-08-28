defmodule Philomena.Adverts.Advert do
  use Ecto.Schema
  import Ecto.Changeset

  schema "adverts" do
    field :image, :string
    field :link, :string
    field :title, :string
    field :clicks, :integer, default: 0
    field :impressions, :integer, default: 0
    field :live, :boolean, default: false
    field :start_date, :naive_datetime
    field :finish_date, :naive_datetime
    field :restrictions, :string
    field :notes, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(advert, attrs) do
    advert
    |> cast(attrs, [])
    |> validate_required([])
  end
end
