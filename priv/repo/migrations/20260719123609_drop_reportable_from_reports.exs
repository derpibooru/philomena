defmodule Philomena.Repo.Migrations.DropReportableFromReports do
  use Ecto.Migration

  def up do
    alter table(:reports) do
      remove :reportable_type
      remove :reportable_id
    end
  end

  def down do
    alter table(:reports) do
      add :reportable_id, :integer
      add :reportable_type, :string
    end
  end
end
