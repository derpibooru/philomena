defmodule Philomena.Repo.Migrations.RewriteSourceChanges do
  use Ecto.Migration

  def up do
    rename table(:source_changes), to: table(:old_source_changes)

    execute(
      "alter index index_source_changes_on_image_id rename to index_old_source_changes_on_image_id"
    )

    execute(
      "alter index index_source_changes_on_user_id rename to index_old_source_changes_on_user_id"
    )

    execute("alter index index_source_changes_on_ip rename to index_old_source_changes_on_ip")

    execute(
      "alter table old_source_changes rename constraint source_changes_pkey to old_source_changes_pkey"
    )

    execute("alter sequence source_changes_id_seq rename to old_source_changes_id_seq")

    create table(:source_changes) do
      add :image_id, references(:images, on_update: :update_all, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, on_update: :update_all, on_delete: :delete_all)
      add :ip, :inet, null: false
      timestamps(inserted_at: :created_at)

      add :added, :boolean, null: false
      add :fingerprint, :string
      add :user_agent, :string, default: ""
      add :referrer, :string, default: ""
      add :value, :string, null: false
    end

    alter table(:image_sources) do
      remove :id
      modify :source, :string
    end

    create index(:image_sources, [:image_id, :source],
             name: "index_image_source_on_image_id_and_source",
             unique: true
           )

    drop constraint(:image_sources, :length_must_be_valid,
           check: "length(source) >= 8 and length(source) <= 1024"
         )

    create constraint(:image_sources, :image_sources_source_check,
             check: "source ~* '^https?://'"
           )

    # These statements should not be ran by the migration in production.
    # Run them manually in psql instead.
    if System.get_env("MIX_ENV") != "prod" do
      execute("""
      insert into image_sources (image_id, source)
      select id as image_id, substr(source_url, 1, 255) as source from images
      where source_url is not null and source_url ~* '^https?://';
      """)

      # First insert the "added" changes...
      execute("""
      with ranked_added_source_changes as (
        select
          image_id, user_id, ip, created_at, updated_at, fingerprint, user_agent,
          substr(referrer, 1, 255) as referrer,
          substr(new_value, 1, 255) as value, true as added,
          rank() over (partition by image_id order by created_at asc)
          from old_source_changes
          where new_value is not null
      )
      insert into source_changes
      (image_id, user_id, ip, created_at, updated_at, fingerprint, user_agent, referrer, value, added)
      select image_id, user_id, ip, created_at, updated_at, fingerprint, user_agent, referrer, value, added
      from ranked_added_source_changes
      where "rank" > 1;
      """)

      # ...then the "removed" changes
      execute("""
      with ranked_removed_source_changes as (
        select
          image_id, user_id, ip, created_at, updated_at, fingerprint, user_agent,
          substr(referrer, 1, 255) as referrer,
          substr(new_value, 1, 255) as value, false as added,
          rank() over (partition by image_id order by created_at desc)
          from old_source_changes
          where new_value is not null
      )
      insert into source_changes
      (image_id, user_id, ip, created_at, updated_at, fingerprint, user_agent, referrer, value, added)
      select image_id, user_id, ip, created_at, updated_at, fingerprint, user_agent, referrer, value, added
      from ranked_removed_source_changes
      where "rank" > 1;
      """)
    end

    create index(:source_changes, [:image_id], name: "index_source_changes_on_image_id")
    create index(:source_changes, [:user_id], name: "index_source_changes_on_user_id")
    create index(:source_changes, [:ip], name: "index_source_changes_on_ip")
  end

  def down do
    drop table(:source_changes)
    rename table(:old_source_changes), to: table(:source_changes)

    execute(
      "alter index index_old_source_changes_on_image_id rename to index_source_changes_on_image_id"
    )

    execute(
      "alter index index_old_source_changes_on_user_id rename to index_source_changes_on_user_id"
    )

    execute("alter index index_old_source_changes_on_ip rename to index_source_changes_on_ip")

    execute(
      "alter table source_changes rename constraint old_source_changes_pkey to source_changes_pkey"
    )

    execute("alter sequence old_source_changes_id_seq rename to source_changes_id_seq")

    execute("truncate image_sources")

    drop constraint(:image_sources, :image_sources_source_check, check: "source ~* '^https?://'")

    create constraint(:image_sources, :length_must_be_valid,
             check: "length(source) >= 8 and length(source) <= 1024"
           )

    drop index(:image_sources, [:image_id, :source],
           name: "index_image_source_on_image_id_and_source"
         )

    alter table(:image_sources) do
      modify :source, :text
    end
  end
end
