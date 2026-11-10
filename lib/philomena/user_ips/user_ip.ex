defmodule Philomena.UserIps.UserIp do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  @type t :: %__MODULE__{}

  schema "user_ips" do
    belongs_to :user, User

    field :ip, EctoNetwork.INET
    field :uses, :integer, default: 1

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def insert_fields do
    [:user_id, :ip, :uses]
  end

  @doc false
  def changeset(user_ip, attrs \\ %{}) do
    user_ip
    |> cast(attrs, [:ip])
    |> validate_required([:ip])
  end
end
