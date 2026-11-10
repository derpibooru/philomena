defmodule Philomena.Repo.Migrations.AnonymousGalleries do
  use Ecto.Migration

  def change do
    alter table(:galleries) do
      add :anonymous, :boolean, null: false, default: false
    end
  end
end
