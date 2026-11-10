defmodule Philomena.Repo.Migrations.AddTagNameLengthLimit do
  use Ecto.Migration

  # Deleting here cannot clean up OpenSearch: stale documents for the deleted
  # tags (and for images that carried them) remain until the next reindex.
  def up do
    execute("DELETE FROM tags WHERE octet_length(name) > 255")

    create constraint(:tags, :tags_name_length_check, check: "octet_length(name) <= 255")
  end

  def down do
    drop constraint(:tags, :tags_name_length_check)
  end
end
