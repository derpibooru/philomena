defmodule Philomena.Repo.Migrations.CreateInternalRules do
  use Ecto.Migration

  # System reports reference these rules by name.
  def change do
    execute(
      """
      WITH inserted AS (
        INSERT INTO rules (name, position, hidden, internal, created_at, updated_at)
        VALUES
          ('Verification', 1001, true, true, NOW(), NOW()),
          ('Approval', 1002, true, true, NOW(), NOW()),
          ('Review', 1003, true, true, NOW(), NOW()),
          ('System', 1004, true, true, NOW(), NOW())
        ON CONFLICT DO NOTHING
        RETURNING id, name, created_at
      )
      INSERT INTO rule_versions (rule_id, name, created_at)
      SELECT id, name, created_at FROM inserted;
      """,
      ""
    )
  end
end
