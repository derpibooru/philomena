defmodule Philomena.Repo.Migrations.AddUserDelayHomeImages do
  use Ecto.Migration

  def change do
    alter table("users") do
      add :delay_home_images, :boolean, default: true
      add :staff_delay_home_images, :boolean, default: false
    end
  end
end
