defmodule Philomena.Bans.Subnet do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  schema "subnet_bans" do
    belongs_to :banning_user, User

    field :reason, :string
    field :note, :string
    field :enabled, :boolean, default: true
    field :valid_until, :utc_datetime
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
