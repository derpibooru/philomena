defmodule Philomena.Repo.Migrations.FixVariousCounters do
  use Ecto.Migration

  def change do
    alter table(:user_statistics) do
      add :topics_count, :integer, default: 0, null: false
    end

    rename table(:user_statistics), :forum_posts, to: :posts_count
    rename table(:user_statistics), :uploads, to: :images_count
    rename table(:user_statistics), :votes_cast, to: :image_votes_count
    rename table(:user_statistics), :comments_posted, to: :comments_count
    rename table(:user_statistics), :images_favourited, to: :image_faves_count
    rename table(:user_statistics), :metadata_updates, to: :metadata_updates_count

    rename table(:users), :forum_posts_count, to: :posts_count
    rename table(:users), :topic_count, to: :topics_count
    rename table(:users), :uploads_count, to: :images_count
    rename table(:users), :votes_cast_count, to: :image_votes_count
    rename table(:users), :comments_posted_count, to: :comments_count
    rename table(:users), :images_favourited_count, to: :image_faves_count

    # These statements should not be run by the migration in production.
    # Run them manually in psql after this migration instead.
    if System.get_env("MIX_ENV") != "prod" do
      execute "UPDATE users SET topics_count = (SELECT count(*) FROM topics WHERE user_id = users.id AND hidden_from_users IS FALSE)",
              "UPDATE users SET topics_count = 0"

      execute "UPDATE users SET posts_count = (SELECT count(*) FROM posts WHERE user_id = users.id AND destroyed_content IS FALSE)",
              "UPDATE users SET posts_count = (SELECT count(*) FROM posts WHERE user_id = users.id)"

      execute "UPDATE topics SET post_count = (SELECT count(*) FROM posts WHERE topic_id = topics.id AND destroyed_content IS FALSE)",
              "UPDATE topics SET post_count = (SELECT count(*) FROM posts WHERE topic_id = topics.id)"

      execute "UPDATE forums SET topic_count = (SELECT count(*) FROM topics WHERE forum_id = forums.id AND hidden_from_users IS FALSE)",
              "UPDATE forums SET topic_count = (SELECT count(*) FROM topics WHERE forum_id = forums.id)"

      execute "UPDATE forums SET post_count = (SELECT count(*) FROM posts JOIN topics ON posts.topic_id = topics.id WHERE topics.forum_id = forums.id AND topics.hidden_from_users IS FALSE AND posts.destroyed_content IS FALSE)",
              "UPDATE forums SET post_count = (SELECT count(*) FROM posts JOIN topics ON posts.topic_id = topics.id WHERE topics.forum_id = forums.id)"

      execute "UPDATE images SET comments_count = (SELECT count(*) FROM comments WHERE image_id = images.id AND destroyed_content IS FALSE)",
              "UPDATE images SET comments_count = (SELECT count(*) FROM comments WHERE image_id = images.id)"

      execute "UPDATE users SET comments_count = (SELECT count(*) FROM comments WHERE user_id = users.id AND destroyed_content IS FALSE)",
              "UPDATE users SET comments_count = (SELECT count(*) FROM comments WHERE user_id = users.id)"
    end
  end
end
