defmodule Philomena.Repo.Migrations.AddApprovalQueue do
  use Ecto.Migration

  def change do
    alter table("reports") do
      add :system, :boolean, default: false
    end

    alter table("images") do
      add :approved, :boolean, default: false
    end

    alter table("comments") do
      add :approved, :boolean, default: false
    end

    alter table("posts") do
      add :approved, :boolean, default: false
    end

    alter table("messages") do
      add :approved, :boolean, default: false
    end

    alter table("users") do
      add :verified, :boolean, default: false
    end

    create index(:images, [:hidden_from_users, :approved],
             where: "hidden_from_users = false and approved = false"
           )

    create index(:reports, [:system], where: "system = true")
  end
end
