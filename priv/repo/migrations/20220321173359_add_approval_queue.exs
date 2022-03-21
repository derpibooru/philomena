defmodule Philomena.Repo.Migrations.AddApprovalQueue do
  use Ecto.Migration

  def change do
    alter table("reports") do
      add :system, :boolean, default: false
    end

    alter table("images") do
      add :approved_at, :utc_datetime
    end

    alter table("comments") do
      add :approved_at, :utc_datetime
    end

    alter table("posts") do
      add :approved_at, :utc_datetime
    end

    alter table("topics") do
      add :approved_at, :utc_datetime
    end

    alter table("users") do
      add :verified, :boolean, default: false
    end
  end
end
