defmodule Philomena.Repo.Migrations.AddGameTables do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :name, :varchar, null: false

      timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
    end

    create table(:game_teams) do
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :name, :varchar, null: false
      add :points, :integer, default: 0

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create table(:game_players) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :team_id, references(:game_teams, on_delete: :delete_all), null: false
      add :points, :integer, default: 0

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    execute(
      "insert into games(name, created_at) values('April Fools 2023', '2023-03-31T00:00:00Z');"
    )

    execute(
      "insert into game_teams(game_id, name, points, created_at, updated_at) values(1, 'New Lunar Republic', 0, '2023-03-31T00:00:00Z', '2023-03-31T00:00:00Z');"
    )

    execute(
      "insert into game_teams(game_id, name, points, created_at, updated_at) values(1, 'Solar Empire', 0, '2023-03-31T00:00:00Z', '2023-03-31T00:00:00Z');"
    )
  end
end
