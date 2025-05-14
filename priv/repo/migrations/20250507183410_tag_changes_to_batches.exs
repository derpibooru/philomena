defmodule Philomena.Repo.Migrations.TagChangesToBatches do
  use Ecto.Migration

  # Deliberately retain old tag_changes table,
  # in order to retain the ability to rollback easily.
  # TODO: remove in 2.0 release
  def up do
    rename table(:tag_changes), to: table(:tag_changes_legacy)

    create table(:tag_changes) do
      add :image_id, references(:images, on_update: :update_all, on_delete: :delete_all),
        null: false

      # if user is somehow gone, just null the column to turn this tag change into an anon tag change.
      add :user_id, references(:users, on_update: :update_all, on_delete: :nilify_all)
      add :ip, :inet, null: false
      add :fingerprint, :string, null: false
      timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
    end

    create table(:tag_change_tags, primary_key: false) do
      add :tag_change_id,
          references(:tag_changes, on_update: :update_all, on_delete: :delete_all),
          null: false

      add :tag_id, references(:tags, on_update: :update_all, on_delete: :delete_all), null: false
      add :added, :boolean, null: false
    end

    create index(:tag_changes, [:user_id])
    create index(:tag_changes, [:image_id])
    create index(:tag_changes, ["ip inet_ops"], using: :gist)
    create index(:tag_changes, [:fingerprint])

    create index(:tag_change_tags, [:tag_change_id, :tag_id], unique: true)
    create index(:tag_change_tags, [:tag_id])

    # In production, this should be triggered manually.
    # Wrap between BEGIN and COMMIT, for safety.
    if System.get_env("MIX_ENV") != "prod" do
      execute("""
        WITH grouped AS (
          SELECT
            MIN(id) AS first_id,
            image_id,
            COALESCE(user_id::text, ip::text, '(none)') AS user,
            FLOOR(EXTRACT(EPOCH FROM created_at)/5)::bigint AS bucket,
            MIN(created_at) AS real_created_at
          FROM tag_changes_legacy
          WHERE tag_id IS NOT NULL
          GROUP BY image_id, COALESCE(user_id::text, ip::text, '(none)'), FLOOR(EXTRACT(EPOCH FROM created_at)/5)::bigint
        ),
        insert_tag_changes AS (
          INSERT INTO tag_changes (image_id, user_id, ip, fingerprint, created_at)
            SELECT
              g.image_id,
              tc.user_id,
              COALESCE(tc.ip, inet '127.0.0.1'),
              COALESCE(tc.fingerprint, 'ffff'),
              g.real_created_at
            FROM grouped g
            JOIN tag_changes_legacy tc ON tc.id = g.first_id
          RETURNING
            id as tag_change_id,
            image_id,
            COALESCE(user_id::text, ip::text, '(none)') AS user,
            FLOOR(EXTRACT(EPOCH FROM created_at)/5)::bigint AS bucket
        ),
        insert_tag_change_tags AS (
          INSERT INTO tag_change_tags (tag_change_id, tag_id, added)
            SELECT
              itc.tag_change_id,
              tc.tag_id,
              tc.added
            FROM tag_changes_legacy tc
            JOIN grouped g
              ON g.image_id = tc.image_id
              AND g.user = COALESCE(tc.user_id::text, tc.ip::text, '(none)')
              AND g.bucket = FLOOR(EXTRACT(EPOCH FROM tc.created_at)/5)::bigint
            JOIN insert_tag_changes itc
              ON itc.image_id = g.image_id
              AND itc.user = g.user
              AND itc.bucket = g.bucket
            WHERE tc.tag_id IS NOT NULL
            ORDER BY tc.created_at DESC
          ON CONFLICT DO NOTHING
          RETURNING
            tag_change_id,
            tag_id
        )
        SELECT
          (SELECT COUNT(*) FROM insert_tag_changes),
          (SELECT COUNT(*) FROM insert_tag_change_tags);
      """)
    end
  end

  def down do
    drop table(:tag_change_tags)
    drop table(:tag_changes)
    rename table(:tag_changes_legacy), to: table(:tag_changes)
  end
end
