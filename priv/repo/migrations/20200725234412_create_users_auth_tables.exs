defmodule Philomena.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :confirmed_at, :naive_datetime
    end

    create table(:user_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(inserted_at: :created_at, updated_at: false)
    end

    execute(&email_citext_up/0, &email_citext_down/0)
    create index(:user_tokens, [:user_id])
    create unique_index(:user_tokens, [:context, :token])
  end

  defp email_citext_up() do
    repo().query!("create extension citext")
    repo().query!("alter table users alter column email type citext")
  end

  defp email_citext_down() do
    repo().query!("alter table users alter column email type character varying")
    repo().query!("drop extension citext")
  end
end
