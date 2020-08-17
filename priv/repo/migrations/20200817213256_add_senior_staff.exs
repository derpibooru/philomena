defmodule Philomena.Repo.Migrations.AddSeniorStaff do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :senior_staff, :boolean, default: false
    end
  end
end
