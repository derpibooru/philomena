defmodule Philomena.Repo.Migrations.NormalizeVersions do
  use Ecto.Migration

  # Deliberately retain the old paper_trail versions table (renamed), in order
  # to retain the ability to rollback easily and verify the conversion.
  # Keep versions_legacy while Release.backfill_versions/0 supports deployed
  # installations. Drop it only in a dedicated compatibility cleanup.
  def up do
    rename table(:versions), to: table(:versions_legacy)

    create table(:post_versions) do
      add :post_id, references(:posts, on_update: :update_all, on_delete: :delete_all),
        null: false

      # if the editor is somehow gone, null the column to keep the version row.
      add :user_id, references(:users, on_update: :update_all, on_delete: :nilify_all)
      add :body, :text, null: false, default: ""
      add :edit_reason, :string
      timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
    end

    create index(:post_versions, [:post_id, :created_at])
    create index(:post_versions, [:user_id])

    create table(:comment_versions) do
      add :comment_id, references(:comments, on_update: :update_all, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, on_update: :update_all, on_delete: :nilify_all)
      add :body, :text, null: false, default: ""
      add :edit_reason, :string
      timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
    end

    create index(:comment_versions, [:comment_id, :created_at])
    create index(:comment_versions, [:user_id])

    # In production, the data conversion should be triggered manually after
    # this migration runs and before the new application code starts serving
    # edits: philomena eval "Philomena.Release.backfill_versions()"
    # The gate uses compile-time-baked config rather than MIX_ENV because the
    # production release runtime does not set MIX_ENV; when unset, stay safe
    # and skip.
    if Application.get_env(:philomena, :env, :prod) != :prod do
      for sql <- Philomena.Versions.LegacyBackfill.statements() do
        execute(sql)
      end
    end
  end

  def down do
    drop table(:post_versions)
    drop table(:comment_versions)
    rename table(:versions_legacy), to: table(:versions)
  end
end
