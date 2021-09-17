defmodule Philomena.Repo.Migrations.AddBypassRateLimitsToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :bypass_rate_limits, :boolean, default: false
    end
  end

  def down do
    alter table(:users) do
      remove :bypass_rate_limits
    end
  end
end
