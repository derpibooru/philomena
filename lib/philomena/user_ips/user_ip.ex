defmodule Philomena.UserIps.UserIp do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  schema "user_ips" do
    belongs_to :user, User

    field :ip, EctoNetwork.INET
    field :uses, :integer, default: 0

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(user_ip, attrs) do
    user_ip
    |> cast(attrs, [])
    |> validate_required([])
  end
end
