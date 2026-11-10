defmodule Philomena.Repo.Migrations.CreateRules do
  use Ecto.Migration

  def change do
    create table(:rules) do
      add :name, :string, null: false
      add :title, :string, default: "", null: false
      add :description, :text, default: "", null: false
      add :short_description, :string, default: "", null: false
      add :example, :text, default: "", null: false
      add :position, :integer, null: false
      add :highlight, :boolean, default: false, null: false
      add :hidden, :boolean, default: false, null: false
      add :internal, :boolean, default: false, null: false

      timestamps(inserted_at: :created_at, type: :utc_datetime)
    end

    create index(:rules, [:name], unique: true)
    create index(:rules, [:position], unique: true)

    create table(:rule_versions) do
      add :rule_id, references(:rules, on_update: :update_all, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, on_update: :update_all, on_delete: :nilify_all)

      add :name, :string, default: "", null: false
      add :title, :string, default: "", null: false
      add :description, :text, default: "", null: false
      add :short_description, :string, default: "", null: false
      add :example, :text, default: "", null: false

      timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
    end

    execute(
      """
      INSERT INTO rules (name, title, description, short_description, example, position, highlight, hidden, internal, created_at, updated_at)
      VALUES ('Legacy', '', '', '', '', 1000, false, true, true, NOW(), NOW());
      """,
      ""
    )

    alter table(:reports) do
      add :rule_id, references(:rules, on_delete: :restrict), default: 1
    end

    execute("ALTER TABLE reports ALTER COLUMN rule_id DROP DEFAULT;", "")
  end
end
