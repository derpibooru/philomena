defmodule Philomena.Games do
  @moduledoc """
  The Users context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Games.{Player, Team}

  def create_player(user, attrs \\ %{"points" => 0}) do
    %Player{}
    |> Player.changeset(attrs, user)
    |> Repo.insert()
  end

  def team_scores do
    Team
    |> order_by(asc: :id)
    |> Repo.all()
    |> Enum.map(fn t -> t.points end)
  end
end
