defmodule Philomena.Repo.Migrations.ChangeImageScaleOptionType do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :scale_large_images0, :string, default: "true", null: false
    end

    execute(
      "update users set scale_large_images0 = (case when scale_large_images then 'true' else 'false' end);"
    )

    alter table(:users) do
      remove :scale_large_images
    end

    rename table(:users), :scale_large_images0, to: :scale_large_images
  end
end
