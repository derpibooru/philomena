defmodule Philomena.Repo.Migrations.CreateUserSettings do
  use Ecto.Migration

  # TODO: drop the moved columns (and the dead show_large_thumbnails,
  # fancy_tag_field_in_settings, autorefresh_by_default, show_hidden_items,
  # serve_webm columns) from users in a later cleanup migration.
  def up do
    create table(:user_settings, primary_key: false) do
      add :user_id, references(:users, on_update: :update_all, on_delete: :delete_all),
        primary_key: true

      add :spoiler_type, :string, null: false, default: "static"
      add :theme, :string, null: false, default: "dark-blue"
      add :images_per_page, :integer, null: false, default: 15
      add :comments_per_page, :integer, null: false, default: 20
      add :show_sidebar_and_watched_images, :boolean, null: false, default: true
      add :fancy_tag_field_on_upload, :boolean, null: false, default: true
      add :fancy_tag_field_on_edit, :boolean, null: false, default: true
      add :anonymous_by_default, :boolean, null: false, default: false
      add :scale_large_images, :string, size: 255, null: false, default: "true"
      add :comments_newest_first, :boolean, null: false, default: true
      add :comments_always_jump_to_last, :boolean, null: false, default: true
      add :watch_on_reply, :boolean, null: false, default: true
      add :watch_on_new_topic, :boolean, null: false, default: true
      add :watch_on_upload, :boolean, null: false, default: true
      add :messages_newest_first, :boolean, null: false, default: false
      add :no_spoilered_in_watched, :boolean, null: false, default: false
      add :watched_images_query_str, :text, null: false, default: ""
      add :watched_images_exclude_str, :text, null: false, default: ""
      add :use_centered_layout, :boolean, null: false, default: true
      add :hide_vote_counts, :boolean, null: false, default: false
      add :delay_home_images, :boolean, null: false, default: true
      add :staff_delay_home_images, :boolean, null: false, default: false
      add :borderless_tags, :boolean, null: false, default: false
      add :rounded_tags, :boolean, null: false, default: false

      timestamps(inserted_at: :created_at, type: :utc_datetime)
    end

    if Application.get_env(:philomena, :env, :prod) != :prod do
      execute(Philomena.Users.SettingsBackfill.statement())
    end
  end

  def down do
    drop table(:user_settings)
  end
end
