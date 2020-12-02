defmodule Philomena.Repo.Migrations.RenameUserLinksTable do
  use Ecto.Migration

  def up do
    rename table("user_links"), to: table("artist_links")
    execute "ALTER SEQUENCE user_links_id_seq RENAME TO artist_links_id_seq"

    execute "ALTER INDEX index_user_links_on_aasm_state RENAME TO index_artist_links_on_aasm_state"

    execute "ALTER INDEX index_user_links_on_contacted_by_user_id RENAME TO index_artist_links_on_contacted_by_user_id"

    execute "ALTER INDEX index_user_links_on_next_check_at RENAME TO index_artist_links_on_next_check_at"

    execute "ALTER INDEX index_user_links_on_tag_id RENAME TO index_artist_links_on_tag_id"

    execute "ALTER INDEX index_user_links_on_uri_tag_id_user_id RENAME TO index_artist_links_on_uri_tag_id_user_id"

    execute "ALTER INDEX index_user_links_on_user_id RENAME TO index_artist_links_on_user_id"

    execute "ALTER INDEX index_user_links_on_verified_by_user_id RENAME TO index_artist_links_on_verified_by_user_id"

    execute "ALTER TABLE artist_links RENAME CONSTRAINT user_links_pkey TO artist_links_pkey"
    execute "UPDATE roles SET resource_type='ArtistLink' WHERE resource_type='UserLink'"
  end

  def down do
    rename table("artist_links"), to: table("user_links")
    execute "ALTER SEQUENCE artist_links_id_seq RENAME TO user_links_id_seq"

    execute "ALTER INDEX index_artist_links_on_aasm_state RENAME TO index_user_links_on_aasm_state"

    execute "ALTER INDEX index_artist_links_on_contacted_by_user_id RENAME TO index_user_links_on_contacted_by_user_id"

    execute "ALTER INDEX index_artist_links_on_next_check_at RENAME TO index_user_links_on_next_check_at"

    execute "ALTER INDEX index_artist_links_on_tag_id RENAME TO index_user_links_on_tag_id"

    execute "ALTER INDEX index_artist_links_on_uri_tag_id_user_id RENAME TO index_user_links_on_uri_tag_id_user_id"

    execute "ALTER INDEX index_artist_links_on_user_id RENAME TO index_user_links_on_user_id"

    execute "ALTER INDEX index_artist_links_on_verified_by_user_id RENAME TO index_user_links_on_verified_by_user_id"

    execute "ALTER TABLE user_links RENAME CONSTRAINT artist_links_pkey TO user_links_pkey"
    execute "UPDATE roles SET resource_type='UserLink' WHERE resource_type='ArtistLink'"
  end
end
