defmodule Philomena.UserLinks.UserLink do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_links" do
    belongs_to :user, Philomena.Users.User
    belongs_to :verified_by_user, Philomena.Users.User
    belongs_to :contacted_by_user, Philomena.Users.User
    belongs_to :tag, Philomena.Tags.Tag

    field :aasm_state, :string
    field :uri, :string
    field :hostname, :string
    field :path, :string
    field :verification_code, :string
    field :public, :boolean, default: true
    field :next_check_at, :naive_datetime
    field :contacted_at, :naive_datetime

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(user_link, attrs) do
    user_link
    |> cast(attrs, [])
    |> validate_required([])
  end
end
