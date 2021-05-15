defmodule Philomena.Repo.Migrations.AddIndexPostsOnTopicIdAndTopicPosition do
  use Ecto.Migration

  def up do
    execute("drop index index_posts_on_topic_id_and_topic_position;")

    execute("""
      with mismatched_ranks as (select id,rank from (select id, topic_position, (rank() over (partition by topic_id order by created_at,id asc))-1 as rank from posts) s where s.topic_position <> s.rank)
      update posts set topic_position=mismatched_ranks.rank
      from mismatched_ranks
      where posts.id=mismatched_ranks.id;
    """)

    execute(
      "create unique index index_posts_on_topic_id_and_topic_position on posts (topic_id, topic_position);"
    )
  end

  def down do
    execute("drop index index_posts_on_topic_id_and_topic_position;")

    execute(
      "create index index_posts_on_topic_id_and_topic_position on public.posts (topic_id, topic_position);"
    )
  end
end
