defmodule Philomena.Repo.Migrations.AddReportableAssociationToReports do
  use Ecto.Migration

  @associations [
    {:image_id, "Image", "images"},
    {:comment_id, "Comment", "comments"},
    {:post_id, "Post", "posts"},
    {:reported_user_id, "User", "users"},
    {:commission_id, "Commission", "commissions"},
    {:conversation_id, "Conversation", "conversations"},
    {:gallery_id, "Gallery", "galleries"}
  ]

  def up do
    alter table(:reports) do
      add :image_id, references(:images, on_delete: :nilify_all)
      add :comment_id, references(:comments, on_delete: :nilify_all)
      add :post_id, references(:posts, on_delete: :nilify_all)
      add :reported_user_id, references(:users, on_delete: :nilify_all)
      add :commission_id, references(:commissions, on_delete: :nilify_all)
      add :conversation_id, references(:conversations, on_delete: :nilify_all)
      add :gallery_id, references(:galleries, on_delete: :nilify_all)
    end

    flush()

    # Backfill each column from the legacy polymorphic pair. The EXISTS
    # guard leaves reports whose target has been deleted all-NULL rather than
    # pointing them at a nonexistent row; those orphans are retained as
    # moderation audit trail.
    for {column, type, table} <- @associations do
      execute("""
      UPDATE reports r
      SET #{column} = r.reportable_id
      WHERE r.reportable_type = '#{type}'
        AND EXISTS (SELECT 1 FROM #{table} t WHERE t.id = r.reportable_id)
      """)
    end

    create constraint(:reports, :reports_reportable_association_null,
             check:
               "num_nonnulls(image_id, comment_id, post_id, reported_user_id, commission_id, conversation_id, gallery_id) <= 1"
           )

    create index(:reports, [:image_id], where: "image_id IS NOT NULL")
    create index(:reports, [:comment_id], where: "comment_id IS NOT NULL")
    create index(:reports, [:post_id], where: "post_id IS NOT NULL")
    create index(:reports, [:reported_user_id], where: "reported_user_id IS NOT NULL")
    create index(:reports, [:commission_id], where: "commission_id IS NOT NULL")
    create index(:reports, [:conversation_id], where: "conversation_id IS NOT NULL")
    create index(:reports, [:gallery_id], where: "gallery_id IS NOT NULL")
  end

  def down do
    drop constraint(:reports, :reports_reportable_association_null)

    alter table(:reports) do
      remove :image_id
      remove :comment_id
      remove :post_id
      remove :reported_user_id
      remove :commission_id
      remove :conversation_id
      remove :gallery_id
    end
  end
end
