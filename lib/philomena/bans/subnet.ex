defmodule Philomena.Bans.Subnet do
  use Ecto.Schema
  import Ecto.Changeset

  schema "subnet_bans" do
    belongs_to :banning_user, Philomena.Users.User

    field :reason, :string
    field :note, :string
    field :enabled, :boolean, default: true
    field :valid_until, :naive_datetime
    field :specification, EctoNetwork.INET
    field :generated_ban_id, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(subnet, attrs) do
    subnet
    |> cast(attrs, [])
    |> validate_required([])
  end
end
