defmodule Philomena.Badges.Award do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Badges.Badge
  alias Philomena.Users.User

  schema "badge_awards" do
    belongs_to :user, User
    belongs_to :awarded_by, User
    belongs_to :badge, Badge

    field :label, :string
    field :awarded_on, :utc_datetime
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
