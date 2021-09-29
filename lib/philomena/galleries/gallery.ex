defmodule Philomena.Galleries.Gallery do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Images.Image
  alias Philomena.Users.User
  alias Philomena.Galleries.Interaction
  alias Philomena.Galleries.Subscription

  schema "galleries" do
    belongs_to :thumbnail, Image, source: :thumbnail_id
    belongs_to :creator, User, source: :creator_id
    has_many :interactions, Interaction
    has_many :subscriptions, Subscription
    has_many :subscribers, through: [:subscriptions, :user]

    field :title, :string
    field :spoiler_warning, :string, default: ""
    field :description, :string, default: ""
    field :image_count, :integer
    field :order_position_asc, :boolean

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(gallery, attrs) do
    gallery
    |> cast(attrs, [:thumbnail_id, :title, :spoiler_warning, :description, :order_position_asc])
    |> validate_required([:title, :thumbnail_id])
    |> validate_length(:title, max: 100, count: :bytes)
    |> validate_length(:spoiler_warning, max: 20, count: :bytes)
    |> validate_length(:description, max: 10_000, count: :bytes)
    |> foreign_key_constraint(:thumbnail_id, name: :fk_rails_792181eb40)
  end

  @doc false
  def creation_changeset(gallery, attrs, user) do
    changeset(gallery, attrs)
    |> change(creator: user)
    |> cast_assoc(:interactions, with: &Interaction.changeset/2)
  end
end
