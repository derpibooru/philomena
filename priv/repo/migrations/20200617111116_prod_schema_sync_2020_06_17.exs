defmodule Philomena.Repo.Migrations.ProdSchemaSync20200617 do
  use Ecto.Migration

  def change do
    execute(
      "CREATE INDEX index_comments_on_image_id_and_created_at ON public.comments USING btree (image_id, created_at);"
    )

    execute("DROP INDEX index_dnp_entries_on_modifying_user_id;")

    execute(
      "CREATE INDEX index_dnp_entries_on_aasm_state_filtered ON public.dnp_entries USING btree (aasm_state) WHERE ((aasm_state)::text = ANY (ARRAY[('requested'::character varying)::text, ('claimed'::character varying)::text, ('rescinded'::character varying)::text, ('acknowledged'::character varying)::text]));"
    )

    execute(
      "CREATE INDEX index_duplicate_reports_on_state_filtered ON public.duplicate_reports USING btree (state) WHERE ((state)::text = ANY (ARRAY[('open'::character varying)::text, ('claimed'::character varying)::text]));"
    )

    execute("CREATE INDEX index_filters_on_name ON public.filters USING btree (name);")

    execute(
      "CREATE INDEX index_filters_on_system ON public.filters USING btree (system) WHERE (system = true);"
    )

    execute(
      "CREATE UNIQUE INDEX index_gallery_interactions_on_gallery_id_and_image_id ON public.gallery_interactions USING btree (gallery_id, image_id);"
    )

    execute(
      "CREATE INDEX index_gallery_interactions_on_gallery_id_and_position ON public.gallery_interactions USING btree (gallery_id, \"position\");"
    )

    execute("DROP INDEX index_images_on_first_seen_at;")
    execute("DROP INDEX index_notifications_on_actor_id_and_actor_type;")

    execute(
      "CREATE UNIQUE INDEX index_notifications_on_actor_id_and_actor_type ON public.notifications USING btree (actor_id, actor_type);"
    )

    execute(
      "CREATE INDEX index_subnet_bans_on_specification ON public.subnet_bans USING gist (specification inet_ops);"
    )

    execute(
      "CREATE INDEX index_tag_changes_on_fingerprint ON public.tag_changes USING btree (fingerprint);"
    )

    execute(
      "CREATE INDEX index_tag_changes_on_ip ON public.tag_changes USING gist (ip inet_ops);"
    )

    execute("DROP INDEX index_tags_on_name;")
    execute("CREATE UNIQUE INDEX index_tags_on_name ON public.tags USING btree (name);")
    execute("DROP INDEX index_tags_on_slug;")
    execute("CREATE UNIQUE INDEX index_tags_on_slug ON public.tags USING btree (slug);")
    execute("DROP INDEX index_topics_on_sticky;")
    execute("DROP INDEX index_user_bans_on_created_at;")

    execute(
      "CREATE INDEX index_user_bans_on_created_at ON public.user_bans USING btree (created_at DESC);"
    )

    execute("DROP INDEX index_users_on_name;")
    execute("CREATE UNIQUE INDEX index_users_on_name ON public.users USING btree (name);")
    execute("DROP INDEX index_users_on_slug;")
    execute("CREATE UNIQUE INDEX index_users_on_slug ON public.users USING btree (slug)")

    execute(
      "CREATE INDEX index_users_on_watched_tag_ids ON public.users USING gin (watched_tag_ids);"
    )

    execute("DROP INDEX index_adverts_on_live;")
    execute("DROP INDEX index_commissions_on_categories;")
  end
end
