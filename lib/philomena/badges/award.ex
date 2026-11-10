defmodule Philomena.Badges.Award do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Badges.Badge
  alias Philomena.Users.User

  @type t :: %__MODULE__{}

  schema "badge_awards" do
    belongs_to :user, User
    belongs_to :awarded_by, User
    belongs_to :badge, Badge

    field :awarded_on, :utc_datetime
    field :label, :string, default: ""
    field :reason, :string, default: ""
    field :badge_name, :string, default: ""

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(badge_award, attrs \\ %{}) do
    badge_award
    |> cast(attrs, [:badge_id, :label, :reason, :badge_name])
    |> put_awarded_on()
    |> validate_required([:badge_id])
    |> foreign_key_constraint(:badge_id, name: :fk_rails_b95340cf70)
  end

  defp put_awarded_on(%{data: %{awarded_on: nil}} = changeset) do
    put_change(changeset, :awarded_on, DateTime.utc_now(:second))
  end

  defp put_awarded_on(changeset), do: changeset
end
