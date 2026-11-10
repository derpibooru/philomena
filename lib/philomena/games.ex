defmodule Philomena.Games do
  @moduledoc """
  The Games context: team event players, teams, and their points.
  """

  import Ecto.Query, warn: false
  alias Philomena.Multi
  alias Philomena.Repo

  alias Philomena.Games.{Player, Team}

  @doc """
  Creates a game player for the given user, assigning them to a team.
  """
  def create_player(user, attrs \\ %{"points" => 0}) do
    %Player{}
    |> Player.changeset(attrs, user)
    |> Repo.insert()
  end

  @doc """
  Returns the point totals of all teams, ordered by team id.
  """
  def team_scores do
    Team
    |> order_by(asc: :id)
    |> Repo.all()
    |> Enum.map(fn t -> t.points end)
  end

  @doc """
  Adds a step to the Multi which removes up to `points` points from the
  player and team of the user returned by `user_id_fun`, when that user
  has a game profile. Used when moderators hide a user's content.
  """
  def put_remove_points(%Multi{} = multi, user_id_fun, points)
      when is_function(user_id_fun, 1) do
    Multi.run(multi, :remove_game_points, fn repo, changes ->
      remove_points(repo, user_id_fun.(changes), points)
    end)
  end

  defp remove_points(_repo, nil, _points), do: {:ok, 0}

  defp remove_points(repo, user_id, points) do
    case repo.one(Player |> where(user_id: ^user_id) |> limit(1)) do
      %Player{} = profile ->
        amount = min(profile.points, points)

        repo.update_all(where(Player, user_id: ^user_id), inc: [points: -amount])
        repo.update_all(where(Team, id: ^profile.team_id), inc: [points: -amount])

        {:ok, amount}

      nil ->
        {:ok, 0}
    end
  end
end
