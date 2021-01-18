defmodule Philomena.UserWhitelists.UserWhitelist do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  schema "user_whitelists" do
    belongs_to :user, User

    field :reason, :string
    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(user_whitelist, attrs) do
    user_whitelist
    |> cast(attrs, [])
    |> validate_required([])
  end
end
