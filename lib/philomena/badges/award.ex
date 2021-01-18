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

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(badge_award, attrs) do
    badge_award
    |> cast(attrs, [:badge_id, :label, :reason, :badge_name])
    |> put_awarded_on()
  end

  defp put_awarded_on(%{data: %{awarded_on: nil}} = changeset) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    put_change(changeset, :awarded_on, now)
  end

  defp put_awarded_on(changeset), do: changeset
end
