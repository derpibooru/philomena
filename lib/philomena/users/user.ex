defmodule Philomena.Users.User do
  alias Philomena.Users.Password

  use Ecto.Schema

  use Pow.Ecto.Schema,
    password_hash_methods: {&Password.hash_pwd_salt/1, &Password.verify_pass/2}

  import Ecto.Changeset

  schema "users" do
    belongs_to :current_filter, Philomena.Filters.Filter
    belongs_to :deleted_by_user, Philomena.Users.User

    # Authentication
    field :email, :string
    field :encrypted_password, :string
    field :password_hash, :string, source: :encrypted_password
    field :reset_password_token, :string
    field :reset_password_sent_at, :naive_datetime
    field :remember_created_at, :naive_datetime
    field :sign_in_count, :integer, default: 0
    field :current_sign_in_at, :naive_datetime
    field :last_sign_in_at, :naive_datetime
    field :current_sign_in_ip, EctoNetwork.INET
    field :last_sign_in_ip, EctoNetwork.INET
    field :otp_required_for_login, :boolean
    field :failed_attempts, :integer
    field :authentication_token, :string
    field :unlock_token, :string
    field :locked_at, :naive_datetime
    field :encrypted_otp_secret, :string
    field :encrypted_otp_secret_iv, :string
    field :encrypted_otp_secret_salt, :string
    field :consumed_timestep, :integer
    field :otp_backup_codes, {:array, :string}
    pow_user_fields()

    # General attributes
    field :name, :string
    field :slug, :string
    field :role, :string, default: "user"
    field :description, :string
    field :avatar, :string

    # Settings
    field :spoiler_type, :string, default: "static"
    field :theme, :string, default: "default"
    field :images_per_page, :integer, default: 15
    field :show_large_thumbnails, :boolean, default: true
    field :show_sidebar_and_watched_images, :boolean, default: true
    field :fancy_tag_field_on_upload, :boolean, default: true
    field :fancy_tag_field_on_edit, :boolean, default: true
    field :fancy_tag_field_in_settings, :boolean, default: true
    field :autorefresh_by_default, :boolean, default: false
    field :anonymous_by_default, :boolean, default: false
    field :scale_large_images, :boolean, default: true
    field :comments_newest_first, :boolean, default: true
    field :comments_always_jump_to_last, :boolean, default: true
    field :comments_per_page, :integer, default: 20
    field :watch_on_reply, :boolean, default: true
    field :watch_on_new_topic, :boolean, default: true
    field :watch_on_upload, :boolean, default: true
    field :messages_newest_first, :boolean, default: false
    field :serve_webm, :boolean, default: false
    field :no_spoilered_in_watched, :boolean, default: false
    field :watched_images_query_str, :string, default: ""
    field :watched_images_exclude_str, :string, default: ""
    field :use_centered_layout, :boolean, default: false
    field :personal_title, :string
    field :show_hidden_items, :boolean, default: false
    field :hide_vote_counts, :boolean, default: false
    field :hide_advertisements, :boolean, default: false

    # Counters
    field :forum_posts_count, :integer, default: 0
    field :topic_count, :integer, default: 0
    field :uploads_count, :integer, default: 0
    field :votes_cast_count, :integer, default: 0
    field :comments_posted_count, :integer, default: 0
    field :metadata_updates_count, :integer, default: 0
    field :images_favourited_count, :integer, default: 0

    # Poorly denormalized associations
    field :recent_filter_ids, {:array, :integer}, default: []
    field :watched_tag_ids, {:array, :integer}, default: []

    # Other stuff
    field :last_donation_at, :naive_datetime
    field :last_renamed_at, :naive_datetime
    field :deleted_at, :naive_datetime
    field :scratchpad, :string
    field :secondary_role, :string
    field :hide_default_role, :boolean, default: false

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> pow_changeset(attrs)
    |> cast(attrs, [])
    |> validate_required([])
  end
end
