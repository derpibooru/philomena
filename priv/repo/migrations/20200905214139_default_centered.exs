defmodule Philomena.Repo.Migrations.DefaultCentered do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :use_centered_layout, :boolean, from: :boolean, default: true
    end
  end
end
