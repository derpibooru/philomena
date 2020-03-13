defmodule Philomena.Repo.Migrations.AddBadgeOrderToUsers do
  use Ecto.Migration

  def up do
    alter table("users") do
      add :badges_order, :text, default: "desc"
    end
  end

  def down do
    alter table("users") do
      remove :badges_order
    end
  end
end
