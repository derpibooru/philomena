defmodule Philomena.UserNameChanges.UserNameChange do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  schema "user_name_changes" do
    belongs_to :user, User
    field :name, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(user_name_change, oldname) do
    user_name_change
    |> change(name: oldname)
    |> validate_required([])
  end
end
