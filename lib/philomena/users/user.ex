defmodule Philomena.Users.User do
  alias Philomena.Users.Password

  use Ecto.Schema

  use Pow.Ecto.Schema,
    password_hash_methods: {&Password.hash_pwd_salt/1, &Password.verify_pass/2}

  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :encrypted_password, :string
    field :password_hash, :string, source: :encrypted_password
    field :reset_password_token, :string
    field :reset_password_sent_at, :naive_datetime
    field :remember_created_at, :naive_datetime
    field :sign_in_count, :integer, default: 0
    field :current_sign_in_at, :naive_datetime
    field :last_sign_in_at, :naive_datetime
    field :current_sign_in_ip, EctoNetwork.INET
    field :last_sign_in_ip, EctoNetwork.INET
    field :otp_required_for_login, :boolean
    field :name, :string

    pow_user_fields()

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> pow_changeset(attrs)
    |> cast(attrs, [])
    |> validate_required([])
  end
end
