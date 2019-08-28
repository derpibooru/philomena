defmodule Philomena.Users.Ip do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_ips" do
    belongs_to :user, Philomena.Users.User

    field :ip, EctoNetwork.INET
    field :uses, :integer, default: 0

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(ip, attrs) do
    ip
    |> cast(attrs, [])
    |> validate_required([])
  end
end
