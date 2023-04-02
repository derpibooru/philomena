defmodule Philomena.Games.Player do
  alias Philomena.Users.User
  alias Philomena.Games.{Game, Team}
  alias Philomena.Repo

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "game_players" do
    belongs_to :user, User
    belongs_to :team, Team
    belongs_to :game, Game

    field :points, :integer
    field :rank_override, :string

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  @doc false
  def changeset(player, attrs, user) do
    player
    |> cast(attrs, [:points])
    |> put_assoc(:user, user)
    |> put_assoc(:game, Repo.one(limit(Game, 1)))
    |> put_assoc(:team, Repo.one(limit(where(Team, [t], t.id == ^(rem(user.id, 2) + 1)), 1)))
    |> validate_required([:points, :user, :game, :team])
  end
end
