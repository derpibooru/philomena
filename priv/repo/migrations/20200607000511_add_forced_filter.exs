defmodule Philomena.Repo.Migrations.AddForcedFilter do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :forced_filter_id, references(:filters), on_delete: :restrict
    end
  end
end
