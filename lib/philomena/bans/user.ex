defmodule Philomena.Bans.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_bans" do
    belongs_to :user, Philomena.Users.User
    belongs_to :banning_user, Philomena.Users.User

    field :reason, :string
    field :note, :string
    field :enabled, :boolean, default: true
    field :valid_until, :naive_datetime
    field :generated_ban_id, :string
    field :override_ip_ban, :boolean, default: false

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [])
    |> validate_required([])
  end
end
