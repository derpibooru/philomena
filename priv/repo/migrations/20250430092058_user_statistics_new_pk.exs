defmodule Philomena.Repo.Migrations.UserStatisticsNewPk do
  use Ecto.Migration

  # Not reversible because we're removing the primary key and the associated sequence.
  def up do
    alter table(:user_statistics) do
      remove :id
      modify :user_id, :integer, primary_key: true
      modify :day, :integer, primary_key: true
    end
  end
end
