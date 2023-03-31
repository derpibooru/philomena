defmodule Philomena.Games.Game do
  alias Philomena.Games

  use Ecto.Schema
  import Ecto.Changeset

  schema "games" do
    has_many :players, Games.Player
    has_many :teams, Games.Team

    field :name, :string

    timestamps(inserted_at: :created_at, updated_at: nil, type: :utc_datetime)
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
