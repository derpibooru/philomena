defmodule Philomena.Repo.Migrations.DropNotableFromModNotes do
  use Ecto.Migration

  def up do
    drop index(:mod_notes, [:notable_type, :notable_id],
           name: :index_mod_notes_on_notable_type_and_notable_id
         )

    alter table(:mod_notes) do
      remove :notable_type
      remove :notable_id
    end
  end

  def down do
    alter table(:mod_notes) do
      add :notable_id, :integer
      add :notable_type, :string
    end

    create index(:mod_notes, [:notable_type, :notable_id],
             name: :index_mod_notes_on_notable_type_and_notable_id
           )
  end
end
