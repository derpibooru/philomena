defmodule Philomena.Repo.Migrations.AddRankOverride do
  use Ecto.Migration

  def change do
    alter table("game_players") do
      add :rank_override, :varchar, default: nil
    end
  end
end
