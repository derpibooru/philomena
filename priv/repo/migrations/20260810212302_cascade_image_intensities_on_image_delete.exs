defmodule Philomena.Repo.Migrations.CascadeImageIntensitiesOnImageDelete do
  use Ecto.Migration

  def change do
    execute(
      """
      ALTER TABLE image_intensities
      DROP CONSTRAINT fk_rails_b861f027a7,
      ADD CONSTRAINT fk_rails_b861f027a7
        FOREIGN KEY (image_id)
        REFERENCES images(id)
        ON DELETE CASCADE
      """,
      """
      ALTER TABLE image_intensities
      DROP CONSTRAINT fk_rails_b861f027a7,
      ADD CONSTRAINT fk_rails_b861f027a7
        FOREIGN KEY (image_id)
        REFERENCES images(id)
      """
    )
  end
end
