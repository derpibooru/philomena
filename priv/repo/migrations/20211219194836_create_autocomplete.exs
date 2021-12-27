defmodule Philomena.Repo.Migrations.CreateAutocomplete do
  use Ecto.Migration

  def change do
    create table(:autocomplete, primary_key: false) do
      add :content, :binary, null: false
      timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
    end
  end
end
