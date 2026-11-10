defmodule Philomena.Users.SettingsBackfill do
  @moduledoc """
  One-time copy of the self-view preference columns from `users` into the
  normalized `user_settings` table, one row per user.

  In production this must run after the schema migration and before the new
  application code begins reading settings from `user_settings`, via
  `Philomena.Release.backfill_user_settings/0`.
  """

  alias Philomena.Repo

  @columns ~w(
    spoiler_type
    theme
    images_per_page
    comments_per_page
    show_sidebar_and_watched_images
    fancy_tag_field_on_upload
    fancy_tag_field_on_edit
    anonymous_by_default
    scale_large_images
    comments_newest_first
    comments_always_jump_to_last
    watch_on_reply
    watch_on_new_topic
    watch_on_upload
    messages_newest_first
    no_spoilered_in_watched
    watched_images_query_str
    watched_images_exclude_str
    use_centered_layout
    hide_vote_counts
    delay_home_images
    staff_delay_home_images
    borderless_tags
    rounded_tags
  )

  @doc """
  Runs the backfill in a single statement.
  """
  # sobelow_skip ["SQL.Query"]
  def run! do
    Repo.query!(statement(), [], timeout: :infinity)

    :ok
  end

  @doc """
  The conversion statement. Also used by the schema migration to run the
  conversion inline outside production.
  """
  def statement do
    """
    INSERT INTO user_settings (user_id, #{Enum.join(@columns, ", ")}, created_at, updated_at)
    SELECT id,
           spoiler_type,
           theme,
           images_per_page,
           comments_per_page,
           show_sidebar_and_watched_images,
           fancy_tag_field_on_upload,
           fancy_tag_field_on_edit,
           anonymous_by_default,
           scale_large_images,
           comments_newest_first,
           comments_always_jump_to_last,
           watch_on_reply,
           watch_on_new_topic,
           watch_on_upload,
           messages_newest_first,
           no_spoilered_in_watched,
           watched_images_query_str,
           watched_images_exclude_str,
           use_centered_layout,
           hide_vote_counts,
           COALESCE(delay_home_images, true),
           COALESCE(staff_delay_home_images, false),
           COALESCE(borderless_tags, false),
           COALESCE(rounded_tags, false),
           now(),
           now()
    FROM users
    ON CONFLICT (user_id) DO NOTHING
    """
  end
end
