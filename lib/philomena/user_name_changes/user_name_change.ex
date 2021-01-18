defmodule Philomena.UserNameChanges.UserNameChange do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  schema "user_name_changes" do
    belongs_to :user, User
    field :name, :string

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(user_name_change, old_name) do
    user_name_change
    |> change(name: old_name)
    |> validate_required([])
  end
end
