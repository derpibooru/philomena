defmodule Philomena.Users.Whitelist do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_whitelists" do
    field :reason, :string
    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(whitelist, attrs) do
    whitelist
    |> cast(attrs, [])
    |> validate_required([])
  end
end
