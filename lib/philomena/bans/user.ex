defmodule Philomena.Bans.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Schema.BanId

  schema "user_bans" do
    belongs_to :user, User
    belongs_to :banning_user, User

    field :reason, :string
    field :note, :string
    field :enabled, :boolean, default: true
    field :valid_until, PhilomenaQuery.Ecto.RelativeDate
    field :generated_ban_id, :string
    field :override_ip_ban, :boolean, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(user_ban, attrs) do
    user_ban
    |> cast(attrs, [:reason, :note, :enabled, :override_ip_ban, :user_id, :valid_until])
    |> BanId.put_ban_id("U")
    |> validate_required([:reason, :enabled, :user_id, :valid_until])
    |> check_constraint(:valid_until, name: :user_ban_duration_must_be_valid)
  end
end
