defmodule Philomena.Commissions.Commission do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Commissions.Item
  alias Philomena.Images.Image
  alias Philomena.Users.User
  alias Philomena.Reports.Report

  @type t :: %__MODULE__{}

  schema "commissions" do
    belongs_to :user, User
    belongs_to :sheet_image, Image
    has_many :items, Item, preload_order: [asc: :base_price, asc: :id]
    has_many :reports, Report

    field :open, :boolean
    field :categories, {:array, :string}, default: []
    field :information, :string, default: ""
    field :contact, :string, default: ""
    field :will_create, :string, default: ""
    field :will_not_create, :string, default: ""
    field :commission_items_count, :integer, default: 0

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(commission, attrs \\ %{}) do
    commission
    |> cast(attrs, [
      :information,
      :contact,
      :will_create,
      :will_not_create,
      :open,
      :sheet_image_id,
      :categories
    ])
    |> drop_blank_categories()
    |> validate_required([:user_id, :information, :contact, :open])
    |> validate_length(:information, max: 1000, count: :bytes)
    |> validate_length(:contact, max: 1000, count: :bytes)
    |> validate_length(:will_create, max: 1000, count: :bytes)
    |> validate_length(:will_not_create, max: 1000, count: :bytes)
    |> validate_subset(:categories, Keyword.values(categories()))
    |> unique_constraint(:user_id, name: :index_commissions_on_user_id)
    |> foreign_key_constraint(:sheet_image_id, name: :fk_rails_3dabda470b)
  end

  defp drop_blank_categories(changeset) do
    categories =
      changeset
      |> get_field(:categories)
      |> Enum.filter(&(&1 not in [nil, ""]))

    change(changeset, categories: categories)
  end

  def categories do
    [
      Anthro: "Anthro",
      "Canon Characters": "Canon Characters",
      Comics: "Comics",
      "Fetish Art": "Fetish Art",
      "Human and EqG": "Human and EqG",
      NSFW: "NSFW",
      "Original Characters": "Original Characters",
      "Original Species": "Original Species",
      Pony: "Pony",
      Requests: "Requests",
      Safe: "Safe",
      Shipping: "Shipping",
      "Violence and Gore": "Violence and Gore"
    ]
  end

  def types do
    [
      "Sketch",
      "Colored Sketch",
      "Inked",
      "Flat Color",
      "Vector",
      "Cel Shaded",
      "Fully Shaded",
      "Traditional",
      "Pixel Art",
      "Animation",
      "Crafted Item",
      "Sculpture",
      "Plushie",
      "Other"
    ]
  end
end
