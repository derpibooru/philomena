defmodule Philomena.Bans.Subnet do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Schema.BanId

  schema "subnet_bans" do
    belongs_to :banning_user, User

    field :reason, :string
    field :note, :string
    field :enabled, :boolean, default: true
    field :valid_until, PhilomenaQuery.Ecto.RelativeDate
    field :specification, EctoNetwork.INET
    field :generated_ban_id, :string

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(subnet_ban, attrs) do
    subnet_ban
    |> cast(attrs, [:reason, :note, :enabled, :specification, :valid_until])
    |> BanId.put_ban_id("S")
    |> validate_required([:reason, :enabled, :specification, :valid_until])
    |> check_constraint(:valid_until, name: :subnet_ban_duration_must_be_valid)
    |> mask_specification()
  end

  defp mask_specification(changeset) do
    specification =
      changeset
      |> get_field(:specification)
      |> case do
        %Postgrex.INET{address: {h1, h2, h3, h4, _h5, _h6, _h7, _h8}, netmask: 128} ->
          %Postgrex.INET{address: {h1, h2, h3, h4, 0, 0, 0, 0}, netmask: 64}

        val ->
          val
      end

    put_change(changeset, :specification, specification)
  end
end
