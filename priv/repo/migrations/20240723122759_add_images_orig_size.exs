defmodule Philomena.Repo.Migrations.AddImagesOrigSize do
  use Ecto.Migration

  def change do
    alter table("images") do
      add :image_orig_size, :integer
    end
  end
end
