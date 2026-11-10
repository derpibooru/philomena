defmodule Philomena.Repo.Migrations.Cleanup do
  use Ecto.Migration

  def change do
    # NULL values
    updates =
      """
      update badge_awards set label='' where label is null;
      update badge_awards set reason='' where reason is null;
      update badge_awards set badge_name='' where badge_name is null;
      update channels set thumbnail_url='' where thumbnail_url is null;
      delete from commission_items where commission_id is null;
      update commission_items set add_ons='' where add_ons is null;
      update commissions set will_create='' where will_create is null;
      update commissions set will_not_create='' where will_not_create is null;
      update comments set ip='127.0.0.1' where ip is null;
      update comments set fingerprint='bd41d8cd98f00b204e9800998ecf8427e' where fingerprint is null;
      update duplicate_reports set reason='' where reason is null;
      update filters set hidden_complex_str='' where hidden_complex_str is null;
      update filters set spoilered_complex_str='' where spoilered_complex_str is null;
      update fingerprint_bans set note='' where note is null;
      update images set ip='127.0.0.1' where ip is null;
      update images set fingerprint='bd41d8cd98f00b204e9800998ecf8427e' where fingerprint is null;
      update posts set ip='127.0.0.1' where ip is null;
      update posts set fingerprint='bd41d8cd98f00b204e9800998ecf8427e' where fingerprint is null;
      update source_changes set fingerprint='bd41d8cd98f00b204e9800998ecf8427e' where fingerprint is null;
      update subnet_bans set note='' where note is null;
      update tag_changes set ip='127.0.0.1' where ip is null;
      update tag_changes set fingerprint='bd41d8cd98f00b204e9800998ecf8427e' where fingerprint is null;
      update user_bans set note='' where note is null;
      """

    # These statements should not be run by the migration in production.
    # Run them manually in psql before this migration instead.
    if direction() == :up and System.get_env("MIX_ENV") != "prod" do
      for stmt <- String.split(updates, "\n") do
        execute(stmt)
      end
    end

    # Missing default values
    missing_default = [
      adverts: [:notes],
      badge_awards: [:label, :reason, :badge_name],
      commission_items: [:add_ons],
      commissions: [:will_create, :will_not_create],
      duplicate_reports: [:reason],
      filters: [:hidden_complex_str, :spoilered_complex_str],
      fingerprint_bans: [:note],
      subnet_bans: [:note],
      user_bans: [:note]
    ]

    for {table, columns} <- missing_default do
      add_default = Enum.map_join(columns, ", ", &"alter column #{&1} set default ''")
      remove_default = Enum.map_join(columns, ", ", &"alter column #{&1} drop default")

      execute(
        "alter table #{table} #{add_default};",
        "alter table #{table} #{remove_default};"
      )
    end

    # Missing NOT NULL constraints
    missing_not_null = [
      adverts: [
        :image,
        :clicks,
        :impressions,
        :live,
        :link,
        :title,
        :notes,
        :start_date,
        :finish_date,
        :restrictions
      ],
      badges: [:image, :priority],
      badge_awards: [:label, :reason, :badge_name],
      channels: [:thumbnail_url],
      comments: [:approved, :anonymous, :destroyed_content, :image_id, :ip, :fingerprint],
      commission_items: [:commission_id, :item_type, :description, :base_price, :add_ons],
      commissions: [:information, :contact, :will_create, :will_not_create],
      duplicate_reports: [:reason],
      filters: [:hidden_complex_str, :spoilered_complex_str],
      fingerprint_bans: [:fingerprint, :note],
      images: [:anonymous, :approved, :ip, :fingerprint, :image_orig_size],
      messages: [:approved],
      posts: [:approved, :ip, :fingerprint],
      reports: [:system],
      source_changes: [:fingerprint],
      subnet_bans: [:note, :specification],
      topics: [:anonymous],
      user_bans: [:note],
      versions: [:created_at],
      roles: [:name, :resource_type]
    ]

    for {table, columns} <- missing_not_null do
      add_not_null = Enum.map_join(columns, ", ", &"alter column #{&1} set not null")
      remove_not_null = Enum.map_join(columns, ", ", &"alter column #{&1} drop not null")

      execute(
        "alter table #{table} #{add_not_null};",
        "alter table #{table} #{remove_not_null};"
      )
    end

    # Unused columns
    alter table(:artist_links) do
      remove :path, :"character varying(255)"
      remove :hostname, :"character varying(255)"
    end

    alter table(:channels) do
      remove :watcher_ids, {:array, :integer}, default: [], null: false
      remove :watcher_count, :integer, default: 0, null: false

      remove :tags, :string

      remove :viewer_minutes_today, :integer, default: 0, null: false
      remove :viewer_minutes_thisweek, :integer, default: 0, null: false
      remove :viewer_minutes_thismonth, :integer, default: 0, null: false
      remove :total_viewer_minutes, :integer, default: 0, null: false
      remove :next_check_at, :"timestamp without time zone"
      remove :last_live_at, :"timestamp without time zone"

      remove :banner_image, :string
      remove :channel_image, :string
      remove :remote_stream_id, :integer
    end

    alter table(:comments) do
      remove :user_agent, :string, default: ""
      remove :referrer, :string, default: ""

      remove :name_at_post_time, :string

      remove :body_textile, :string, default: "", null: false
    end

    alter table(:commission_items) do
      remove :description_textile, :string
      remove :add_ons_textile, :string
    end

    alter table(:commissions) do
      remove :information_textile, :string
      remove :contact_textile, :string
      remove :will_create_textile, :string
      remove :will_not_create_textile, :string
    end

    alter table(:dnp_entries) do
      remove :conditions_textile, :string, default: "", null: false
      remove :reason_textile, :string, default: "", null: false
      remove :instructions_textile, :string, default: "", null: false
    end

    alter table(:forums) do
      remove :watcher_ids, {:array, :integer}, default: [], null: false
      remove :watcher_count, :integer, default: 0, null: false
    end

    alter table(:galleries) do
      remove :watcher_ids, {:array, :integer}, default: [], null: false
      remove :watcher_count, :integer, default: 0, null: false
    end

    alter table(:images) do
      remove :tag_ids, {:array, :integer}, default: [], null: false
      remove :watcher_ids, {:array, :integer}, default: [], null: false
      remove :watcher_count, :integer, default: 0, null: false

      remove :user_agent, :string, default: ""
      remove :referrer, :string, default: ""

      remove :votes_count, :integer, default: 0, null: false

      remove :tag_list_cache, :string
      remove :tag_list_plus_alias_cache, :string
      remove :file_name_cache, :string

      remove :ne_intensity, :"double precision"
      remove :nw_intensity, :"double precision"
      remove :se_intensity, :"double precision"
      remove :sw_intensity, :"double precision"
      remove :average_intensity, :"double precision"

      remove :description_textile, :string, default: "", null: false
      remove :scratchpad_textile, :string
    end

    alter table(:messages) do
      remove :body_textile, :string, default: "", null: false
    end

    alter table(:mod_notes) do
      remove :body_textile, :text, default: "", null: false
    end

    alter table(:poll_votes) do
      remove :rank, :integer
    end

    alter table(:polls) do
      remove :deleted_by_id, references(:users, name: "fk_rails_2bf9149369")

      remove :hidden_from_users, :boolean, default: false, null: false
      remove :deletion_reason, :string, default: "", null: false
    end

    alter table(:posts) do
      remove :user_agent, :string, default: ""
      remove :referrer, :string, default: ""

      remove :name_at_post_time, :string

      remove :body_textile, :string, default: "", null: false
    end

    alter table(:reports) do
      remove :referrer, :string, default: ""

      remove :reason_textile, :string, default: "", null: false
    end

    alter table(:roles) do
      remove :resource_id, :integer

      remove :created_at, :"timestamp without time zone"
      remove :updated_at, :"timestamp without time zone"
    end

    alter table(:source_changes) do
      remove :user_agent, :string, size: 255, default: ""
      remove :referrer, :string, size: 255, default: ""
    end

    alter table(:tags) do
      remove :description_textile, :string, default: ""
    end

    alter table(:topics) do
      remove :watcher_ids, {:array, :integer}, default: [], null: false
      remove :watcher_count, :integer, default: 0, null: false
    end

    alter table(:users) do
      remove :sign_in_count, :integer, default: 0, null: false
      remove :current_sign_in_at, :"timestamp without time zone"
      remove :current_sign_in_ip, :inet
      remove :last_sign_in_at, :"timestamp without time zone"
      remove :last_sign_in_ip, :inet
      remove :unread_notification_ids, {:array, :integer}, default: [], null: false

      remove :last_donation_at, :"timestamp without time zone"

      remove :description_textile, :string
      remove :scratchpad_textile, :text
    end

    # Wrong data type, created by Phoenix (timestamp(0) without time zone)
    for table <- [
          :channel_live_notifications,
          :forum_post_notifications,
          :forum_topic_notifications,
          :gallery_image_notifications,
          :image_comment_notifications,
          :image_merge_notifications,
          :source_changes
        ] do
      alter table(table) do
        modify :created_at, :"timestamp without time zone",
          from: :"timestamp(0) without time zone"

        modify :updated_at, :"timestamp without time zone",
          from: :"timestamp(0) without time zone"
      end
    end

    for table <- [:autocomplete, :moderation_logs, :user_tokens] do
      alter table(table) do
        modify :created_at, :"timestamp without time zone",
          from: :"timestamp(0) without time zone"
      end
    end

    alter table(:users) do
      modify :confirmed_at, :"timestamp without time zone",
        from: :"timestamp(0) without time zone"
    end

    # Wrong data type, created by Rails (timestamp(6) without time zone)
    for table <- [:image_features, :static_pages, :static_page_versions] do
      alter table(table) do
        modify :created_at, :"timestamp without time zone",
          from: :"timestamp(6) without time zone"

        modify :updated_at, :"timestamp without time zone",
          from: :"timestamp(6) without time zone"
      end
    end
  end
end
