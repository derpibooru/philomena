defmodule Philomena.UserWhitelists.UserWhitelist do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_whitelists" do
    field :reason, :string
    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(user_whitelist, attrs) do
    user_whitelist
    |> cast(attrs, [])
    |> validate_required([])
  end
end
