defmodule Philomena.Repo.Migrations.AddNotableAssociationToModNotes do
  use Ecto.Migration

  @associations [
    {:user_id, "User", "users"},
    {:report_id, "Report", "reports"},
    {:dnp_entry_id, "DnpEntry", "dnp_entries"}
  ]

  def up do
    alter table(:mod_notes) do
      add :user_id, references(:users, on_delete: :nilify_all)
      add :report_id, references(:reports, on_delete: :nilify_all)
      add :dnp_entry_id, references(:dnp_entries, on_delete: :nilify_all)
    end

    flush()

    # Backfill each column from the legacy polymorphic pair. The EXISTS
    # guard leaves notes whose target has been deleted all-NULL rather than
    # pointing them at a nonexistent row; those orphans are retained as
    # moderation audit trail.
    for {column, type, table} <- @associations do
      execute("""
      UPDATE mod_notes m
      SET #{column} = m.notable_id
      WHERE m.notable_type = '#{type}'
        AND EXISTS (SELECT 1 FROM #{table} t WHERE t.id = m.notable_id)
      """)
    end

    create constraint(:mod_notes, :mod_notes_notable_association_null,
             check: "num_nonnulls(user_id, report_id, dnp_entry_id) <= 1"
           )

    create index(:mod_notes, [:user_id], where: "user_id IS NOT NULL")
    create index(:mod_notes, [:report_id], where: "report_id IS NOT NULL")
    create index(:mod_notes, [:dnp_entry_id], where: "dnp_entry_id IS NOT NULL")
  end

  def down do
    drop constraint(:mod_notes, :mod_notes_notable_association_null)

    alter table(:mod_notes) do
      remove :user_id
      remove :report_id
      remove :dnp_entry_id
    end
  end
end
