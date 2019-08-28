defmodule Philomena.Badges.Award do
  use Ecto.Schema
  import Ecto.Changeset

  schema "badge_awards" do
    belongs_to :user, Philomena.Users.User
    belongs_to :awarded_by, Philomena.Users.User
    belongs_to :badge, Philomena.Badges.Badge

    field :label, :string
    field :awarded_on, :naive_datetime
    field :reason, :string
    field :badge_name, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(badge_award, attrs) do
    badge_award
    |> cast(attrs, [])
    |> validate_required([])
  end
end
