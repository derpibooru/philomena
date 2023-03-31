defmodule Philomena.Games.Team do
  alias Philomena.Games
  use Ecto.Schema
  import Ecto.Changeset

  schema "game_teams" do
    belongs_to :game, Games.Game
    has_many :players, Games.Player

    field :name, :string
    field :points, :integer

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  @doc false
  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :points])
    |> validate_required([:name, :points])
  end
end
