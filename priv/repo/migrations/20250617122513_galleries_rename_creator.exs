defmodule Philomena.Repo.Migrations.GalleriesRenameCreator do
  use Ecto.Migration

  def change do
    rename table(:galleries), :creator_id, to: :user_id
  end
end
