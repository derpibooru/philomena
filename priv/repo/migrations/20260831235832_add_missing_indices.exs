defmodule Philomena.Repo.Migrations.AddMissingIndices do
  use Ecto.Migration

  def change do
    create index(:user_fingerprints, [:user_id, desc: :updated_at, desc: :id])
    create index(:user_ips, [:user_id, desc: :updated_at, desc: :id])
    create index(:topics, [:forum_id, desc: :last_replied_to_at, desc: :id])
    create index(:topics, [:forum_id, desc: :sticky, desc: :last_replied_to_at, desc: :id])
    create index(:source_changes, [:fingerprint])

    drop index(:user_ips, [:user_id, desc: :updated_at],
           name: :index_user_ips_on_user_id_and_updated_at
         )
  end
end
