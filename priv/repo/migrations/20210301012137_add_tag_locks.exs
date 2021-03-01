defmodule Philomena.Repo.Migrations.AddTagLocks do
  use Ecto.Migration

  def change do
    create table("image_tag_locks", primary_key: false) do
      add :image_id, references(:images, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
    end

    create index("image_tag_locks", [:image_id, :tag_id], unique: true)
    create index("image_tag_locks", [:tag_id])
  end
end
