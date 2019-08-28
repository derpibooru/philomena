defmodule Philomena.Users.NameChange do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_name_changes" do
    belongs_to :user, Philomena.Users.User
    field :name, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(name_change, attrs) do
    name_change
    |> cast(attrs, [])
    |> validate_required([])
  end
end
