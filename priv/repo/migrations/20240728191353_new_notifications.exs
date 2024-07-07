defmodule Philomena.Repo.Migrations.NewNotifications do
  use Ecto.Migration

  @categories [
    channel_live: [channels: :channel_id],
    forum_post: [topics: :topic_id, posts: :post_id],
    forum_topic: [topics: :topic_id],
    gallery_image: [galleries: :gallery_id],
    image_comment: [images: :image_id, comments: :comment_id],
    image_merge: [images: :target_id, images: :source_id]
  ]

  def up do
    for {category, refs} <- @categories do
      create table("#{category}_notifications", primary_key: false) do
        for {target_table_name, reference_name} <- refs do
          add reference_name, references(target_table_name, on_delete: :delete_all), null: false
        end

        add :user_id, references(:users, on_delete: :delete_all), null: false
        timestamps(inserted_at: :created_at, type: :utc_datetime)
        add :read, :boolean, default: false, null: false
      end

      {_primary_table_name, primary_ref_name} = hd(refs)
      create index("#{category}_notifications", [:user_id, primary_ref_name], unique: true)
      create index("#{category}_notifications", [:user_id, "updated_at desc"])
      create index("#{category}_notifications", [:user_id, :read])

      for {_target_table_name, reference_name} <- refs do
        create index("#{category}_notifications", [reference_name])
      end
    end

    insert_statements =
      """
      insert into channel_live_notifications (channel_id, user_id, created_at, updated_at)
      select n.actor_id, un.user_id, n.created_at, n.updated_at
      from unread_notifications un
      join notifications n on un.notification_id = n.id
      where n.actor_type = 'Channel'
      and exists(select 1 from channels c where c.id = n.actor_id)
      and exists(select 1 from users u where u.id = un.user_id);

      insert into forum_post_notifications (topic_id, post_id, user_id, created_at, updated_at)
      select n.actor_id, n.actor_child_id, un.user_id, n.created_at, n.updated_at
      from unread_notifications un
      join notifications n on un.notification_id = n.id
      where n.actor_type = 'Topic'
      and n.actor_child_type = 'Post'
      and n.action = 'posted a new reply in'
      and exists(select 1 from topics t where t.id = n.actor_id)
      and exists(select 1 from posts p where p.id = n.actor_child_id)
      and exists(select 1 from users u where u.id = un.user_id);

      insert into forum_topic_notifications (topic_id, user_id, created_at, updated_at)
      select n.actor_id, un.user_id, n.created_at, n.updated_at
      from unread_notifications un
      join notifications n on un.notification_id = n.id
      where n.actor_type = 'Topic'
      and n.actor_child_type = 'Post'
      and n.action <> 'posted a new reply in'
      and exists(select 1 from topics t where t.id = n.actor_id)
      and exists(select 1 from users u where u.id = un.user_id);

      insert into gallery_image_notifications (gallery_id, user_id, created_at, updated_at)
      select n.actor_id, un.user_id, n.created_at, n.updated_at
      from unread_notifications un
      join notifications n on un.notification_id = n.id
      where n.actor_type = 'Gallery'
      and exists(select 1 from galleries g where g.id = n.actor_id)
      and exists(select 1 from users u where u.id = un.user_id);

      insert into image_comment_notifications (image_id, comment_id, user_id, created_at, updated_at)
      select n.actor_id, n.actor_child_id, un.user_id, n.created_at, n.updated_at
      from unread_notifications un
      join notifications n on un.notification_id = n.id
      where n.actor_type = 'Image'
      and n.actor_child_type = 'Comment'
      and exists(select 1 from images i where i.id = n.actor_id)
      and exists(select 1 from comments c where c.id = n.actor_child_id)
      and exists(select 1 from users u where u.id = un.user_id);

      insert into image_merge_notifications (target_id, source_id, user_id, created_at, updated_at)
      select n.actor_id, regexp_replace(n.action, '[a-z#]+', '', 'g')::bigint, un.user_id, n.created_at, n.updated_at
      from unread_notifications un
      join notifications n on un.notification_id = n.id
      where n.actor_type = 'Image'
      and n.actor_child_type is null
      and exists(select 1 from images i where i.id = n.actor_id)
      and exists(select 1 from images i where i.id = regexp_replace(n.action, '[a-z#]+', '', 'g')::integer)
      and exists(select 1 from users u where u.id = un.user_id);
      """

    # These statements should not be run by the migration in production.
    # Run them manually in psql instead.
    if System.get_env("MIX_ENV") != "prod" do
      for stmt <- String.split(insert_statements, "\n\n") do
        execute(stmt)
      end
    end
  end

  def down do
    for {category, _refs} <- @categories do
      drop table("#{category}_notifications")
    end
  end
end
