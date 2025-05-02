defmodule Philomena.Repo.Migrations.ApproveDeletedImages do
  use Ecto.Migration

  def up do
    execute "UPDATE images SET approved = true WHERE hidden_from_users = true AND approved = false"

    drop index(:images, [:hidden_from_users, :approved])
    create index(:images, [:approved], where: "approved = false")
  end
end
