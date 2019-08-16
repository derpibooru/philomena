defmodule Philomena.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :encrypted_password, :string, default: ""
    field :reset_password_token, :string
    field :reset_password_sent_at, :naive_datetime
    field :remember_created_at, :naive_datetime
    field :sign_in_count, :integer, default: 0
    field :current_sign_in_at, :naive_datetime
    field :last_sign_in_at, :naive_datetime
    field :current_sign_in_ip, EctoNetwork.INET
    field :last_sign_in_ip, EctoNetwork.INET
    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [])
    |> validate_required([])
  end
end
