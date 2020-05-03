defmodule Philomena.Repo.Migrations.CreateImageSources do
  use Ecto.Migration

  def change do
    create table(:image_sources) do
      add :image_id, references(:images), null: false
      add :source, :text, null: false
    end

    create unique_index("image_sources", [:image_id, :source])

    create constraint("image_sources", "length_must_be_valid",
             check: "length(source) between 8 and 1024"
           )
  end
end
