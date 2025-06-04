defmodule Philomena.Repo.Migrations.AddTagOptionsToUsers do
  use Ecto.Migration

  def change do
    alter table("users") do
      add :borderless_tags, :boolean, default: false
      add :rounded_tags, :boolean, default: false
    end
  end
end
