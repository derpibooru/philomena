defmodule Philomena.Repo.Migrations.UniqueCommissionPerUser do
  use Ecto.Migration

  def change do
    drop(index(:commissions, [:user_id], name: :index_commissions_on_user_id))
    create(unique_index(:commissions, [:user_id], name: :index_commissions_on_user_id))
  end
end
