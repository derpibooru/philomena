defmodule Philomena.Bans.Subnet do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  import Philomena.Schema.Time
  import Philomena.Schema.BanId

  schema "subnet_bans" do
    belongs_to :banning_user, User

    field :reason, :string
    field :note, :string
    field :enabled, :boolean, default: true
    field :valid_until, :utc_datetime
    field :specification, EctoNetwork.INET
    field :generated_ban_id, :string

    field :until, :string, virtual: true

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(subnet_ban, attrs) do
    subnet_ban
    |> cast(attrs, [])
    |> propagate_time(:valid_until, :until)
  end

  def save_changeset(subnet_ban, attrs) do
    subnet_ban
    |> cast(attrs, [:reason, :note, :enabled, :specification, :until])
    |> assign_time(:until, :valid_until)
    |> put_ban_id("S")
    |> validate_required([:reason, :enabled, :specification, :valid_until])
  end
end
