defmodule Philomena.Repo.Migrations.CreateModerationLogs do
  use Ecto.Migration

  def change do
    create table(:moderation_logs) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :body, :varchar, null: false
      add :subject_path, :varchar, null: false
      add :type, :varchar, null: false

      timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
    end

    create index(:moderation_logs, [:user_id])
    create index(:moderation_logs, [:type])
    create index(:moderation_logs, [:created_at])
    create index(:moderation_logs, [:user_id, :created_at])
    create index(:moderation_logs, [:type, :created_at])
  end
end
