defmodule Philomena.Users.User do
  alias Philomena.Users.Password
  alias Philomena.Slug

  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Schema.TagList
  alias Philomena.Schema.Search

  alias Philomena.Filters.Filter
  alias Philomena.UserLinks.UserLink
  alias Philomena.Badges
  alias Philomena.Notifications.UnreadNotification
  alias Philomena.Galleries.Gallery
  alias Philomena.Users.User
  alias Philomena.Commissions.Commission
  alias Philomena.Roles.Role
  alias Philomena.UserFingerprints.UserFingerprint
  alias Philomena.UserIps.UserIp
  alias Philomena.Bans.User, as: UserBan
  alias Philomena.Donations.Donation

  @derive {Phoenix.Param, key: :slug}
  @derive {Inspect, except: [:password]}
  schema "users" do
    has_many :links, UserLink
    has_many :verified_links, UserLink, where: [aasm_state: "verified"]
    has_many :public_links, UserLink, where: [public: true, aasm_state: "verified"]
    has_many :galleries, Gallery, foreign_key: :creator_id
    has_many :awards, Badges.Award
    has_many :unread_notifications, UnreadNotification
    has_many :notifications, through: [:unread_notifications, :notification]
    has_many :linked_tags, through: [:verified_links, :tag]
    has_many :user_ips, UserIp
    has_many :user_fingerprints, UserFingerprint
    has_many :bans, UserBan
    has_many :donations, Donation
    has_one :commission, Commission
    many_to_many :roles, Role, join_through: "users_roles", on_replace: :delete

    belongs_to :current_filter, Filter
    belongs_to :forced_filter, Filter
    belongs_to :deleted_by_user, User

    # Authentication
    field :email, :string
    field :password, :string, virtual: true
    field :encrypted_password, :string
    field :hashed_password, :string, source: :encrypted_password
    field :confirmed_at, :naive_datetime
    field :otp_required_for_login, :boolean
    field :authentication_token, :string
    field :failed_attempts, :integer
    # field :unlock_token, :string
    field :locked_at, :naive_datetime
    field :encrypted_otp_secret, :string
    field :encrypted_otp_secret_iv, :string
    field :encrypted_otp_secret_salt, :string
    field :consumed_timestep, :integer
    field :otp_backup_codes, {:array, :string}

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
    field :watched_tag_list, :string, virtual: true

    # Other stuff
    field :last_donation_at, :naive_datetime
    field :last_renamed_at, :naive_datetime
    field :deleted_at, :naive_datetime
    field :scratchpad, :string
    field :secondary_role, :string
    field :hide_default_role, :boolean, default: false

    # For avatar validation/persistence
    field :avatar_width, :integer, virtual: true
    field :avatar_height, :integer, virtual: true
    field :avatar_size, :integer, virtual: true
    field :avatar_mime_type, :string, virtual: true
    field :uploaded_avatar, :string, virtual: true
    field :removed_avatar, :string, virtual: true

    # For mod stuff
    field :role_map, :any, virtual: true

    timestamps(inserted_at: :created_at)
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :password])
    |> validate_name()
    |> validate_email()
    |> validate_password()
    |> put_api_key()
    |> put_slug()
    |> unique_constraints()
  end

  defp validate_name(changeset) do
    changeset
    |> validate_required([:name])
    |> validate_length(:name, max: 50)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Philomena.Repo)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 80)
    |> prepare_changes(&hash_password/1)
  end

  defp hash_password(changeset) do
    password = get_change(changeset, :password)

    changeset
    |> put_change(:hashed_password, Password.hash_pwd_salt(password))
    |> delete_change(:password)
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.
  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password()
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Password.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  def successful_attempt_changeset(user) do
    change(user, failed_attempts: 0)
  end

  def failed_attempt_changeset(user) do
    if not is_integer(user.failed_attempts) or user.failed_attempts < 0 do
      change(user, failed_attempts: 1)
    else
      change(user, failed_attempts: user.failed_attempts + 1)
    end
  end

  def lock_changeset(user) do
    locked_at = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    change(user, locked_at: locked_at)
  end

  def unlock_changeset(user) do
    change(user, locked_at: nil, failed_attempts: 0)
  end

  def changeset(user, attrs) do
    cast(user, attrs, [])
  end

  def update_changeset(user, attrs, roles) do
    user
    |> cast(attrs, [:name, :email, :role, :secondary_role, :hide_default_role])
    |> validate_required([:name, :email, :role])
    |> validate_inclusion(:role, ["user", "assistant", "moderator", "admin"])
    |> put_assoc(:roles, roles)
    |> put_slug()
    |> unique_constraints()
  end

  def filter_changeset(user, filter) do
    changeset = change(user)
    user = changeset.data

    changeset
    |> put_change(:current_filter_id, filter.id)
    |> put_change(
      :recent_filter_ids,
      Enum.take(Enum.uniq([filter.id | user.recent_filter_ids]), 10)
    )
  end

  def spoiler_type_changeset(user, attrs) do
    user
    |> cast(attrs, [:spoiler_type])
    |> validate_required([:spoiler_type])
    |> validate_inclusion(:spoiler_type, ~W(static click hover off))
  end

  def settings_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :watched_tag_list,
      :images_per_page,
      :fancy_tag_field_on_upload,
      :fancy_tag_field_on_edit,
      :anonymous_by_default,
      :scale_large_images,
      :comments_per_page,
      :theme,
      :watched_images_query_str,
      :no_spoilered_in_watched,
      :watched_images_exclude_str,
      :use_centered_layout,
      :hide_vote_counts,
      :comments_newest_first
    ])
    |> validate_required([
      :images_per_page,
      :fancy_tag_field_on_upload,
      :fancy_tag_field_on_edit,
      :anonymous_by_default,
      :scale_large_images,
      :comments_per_page,
      :theme,
      :no_spoilered_in_watched,
      :use_centered_layout,
      :hide_vote_counts
    ])
    |> TagList.propagate_tag_list(:watched_tag_list, :watched_tag_ids)
    |> validate_inclusion(:theme, ~W(default dark light fuchsia green orange))
    |> validate_inclusion(:images_per_page, 15..50)
    |> validate_inclusion(:comments_per_page, 15..100)
    |> Search.validate_search(:watched_images_query_str, user, true)
    |> Search.validate_search(:watched_images_exclude_str, user, true)
  end

  def description_changeset(user, attrs) do
    user
    |> cast(attrs, [:description, :personal_title])
    |> validate_length(:description, max: 10_000, count: :bytes)
    |> validate_length(:personal_title, max: 24, count: :bytes)
    |> validate_format(
      :personal_title,
      ~r/\A((?!site|admin|moderator|assistant|developer|\p{C}).)*\z/iu
    )
  end

  def scratchpad_changeset(user, attrs) do
    user
    |> cast(attrs, [:scratchpad])
  end

  def name_changeset(user, attrs) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    user
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> put_slug
    |> unique_constraints()
    |> put_change(:last_renamed_at, now)
  end

  def avatar_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :avatar,
      :avatar_width,
      :avatar_height,
      :avatar_size,
      :uploaded_avatar,
      :removed_avatar
    ])
    |> validate_required([
      :avatar,
      :avatar_width,
      :avatar_height,
      :avatar_size,
      :uploaded_avatar
    ])
    |> validate_number(:avatar_size, greater_than: 0, less_than_or_equal_to: 300_000)
    |> validate_number(:avatar_width, greater_than: 0, less_than_or_equal_to: 1000)
    |> validate_number(:avatar_height, greater_than: 0, less_than_or_equal_to: 1000)
    |> validate_inclusion(:avatar_mime_type, ~W(image/gif image/jpeg image/png))
  end

  def remove_avatar_changeset(user) do
    user
    |> change(removed_avatar: user.avatar)
    |> change(avatar: nil)
  end

  def watched_tags_changeset(user, watched_tag_ids) do
    change(user, watched_tag_ids: watched_tag_ids)
  end

  def reactivate_changeset(user) do
    change(user, deleted_at: nil, deleted_by_user_id: nil)
  end

  def deactivate_changeset(user, moderator) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    change(user, deleted_at: now, deleted_by_user_id: moderator.id)
  end

  def api_key_changeset(user) do
    put_api_key(user)
  end

  def force_filter_changeset(user, params) do
    user
    |> cast(params, [:forced_filter_id])
    |> foreign_key_constraint(:forced_filter_id)
  end

  def unforce_filter_changeset(user) do
    change(user, forced_filter_id: nil)
  end

  def create_totp_secret_changeset(user) do
    secret = :crypto.strong_rand_bytes(15) |> Base.encode32()
    data = Philomena.Users.Encryptor.encrypt_model(secret)

    user
    |> change(%{
      encrypted_otp_secret: data.secret,
      encrypted_otp_secret_iv: data.iv,
      encrypted_otp_secret_salt: data.salt
    })
  end

  def consume_totp_token_changeset(changeset, params) do
    changeset = change(changeset, %{})
    user = changeset.data
    token = extract_token(params)

    cond do
      totp_valid?(user, token) ->
        changeset
        |> change(%{consumed_timestep: String.to_integer(token)})

      backup_code_valid?(user, token) ->
        changeset
        |> change(%{otp_backup_codes: remove_backup_code(user, token)})

      true ->
        changeset
        |> add_error(:twofactor_token, "Invalid token")
    end
  end

  def totp_changeset(changeset, params, backup_codes) do
    %{"user" => %{"current_password" => password}} = params
    changeset = change(changeset, %{})
    user = changeset.data

    cond do
      !!user.otp_required_for_login and valid_password?(user, password) ->
        # User wants to disable TOTP
        changeset
        |> consume_totp_token_changeset(params)
        |> disable_totp_changeset()

      !user.otp_required_for_login and valid_password?(user, password) ->
        # User wants to enable TOTP
        changeset
        |> consume_totp_token_changeset(params)
        |> enable_totp_changeset(backup_codes)

      true ->
        add_error(changeset, :current_password, "is invalid")
    end
  end

  def random_backup_codes do
    1..10
    |> Enum.map(fn _i ->
      :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
    end)
  end

  def totp_qrcode(user) do
    secret = totp_secret(user)

    provisioning_uri = %URI{
      scheme: "otpauth",
      host: "totp",
      path: "/YourBooruName:" <> user.email,
      query:
        URI.encode_query(%{
          secret: secret,
          issuer: "YourBooruName"
        })
    }

    png =
      QRCode.to_png(URI.to_string(provisioning_uri))
      |> Base.encode64()

    "data:image/png;base64," <> png
  end

  def totp_secret(user) do
    Philomena.Users.Encryptor.decrypt_model(
      user.encrypted_otp_secret,
      user.encrypted_otp_secret_iv,
      user.encrypted_otp_secret_salt
    )
  end

  defp enable_totp_changeset(user, backup_codes) do
    hashed_codes = Enum.map(backup_codes, &Password.hash_pwd_salt/1)

    change(user, %{
      otp_required_for_login: true,
      otp_backup_codes: hashed_codes
    })
  end

  defp disable_totp_changeset(user) do
    change(user, %{
      otp_required_for_login: false,
      otp_backup_codes: [],
      encrypted_otp_secret: nil,
      encrypted_otp_secret_iv: nil,
      encrypted_otp_secret_salt: nil
    })
  end

  defp unique_constraints(changeset) do
    changeset
    |> unique_constraint(:name, name: :index_users_on_name)
    |> unique_constraint(:slug, name: :index_users_on_slug)
    |> unique_constraint(:email, name: :index_users_on_email)
    |> unique_constraint(:authentication_token, name: :index_users_on_authentication_token)
  end

  defp extract_token(%{"user" => %{"twofactor_token" => t}}),
    do: to_string(t)

  defp extract_token(_params),
    do: ""

  defp put_api_key(changeset) do
    key = :crypto.strong_rand_bytes(15) |> Base.url_encode64()

    change(changeset, authentication_token: key)
  end

  defp put_slug(changeset) do
    name = get_field(changeset, :name)

    put_change(changeset, :slug, Slug.slug(name))
  end

  defp totp_valid?(user, token) do
    case Integer.parse(token) do
      {int_token, _rest} ->
        int_token != user.consumed_timestep and
          :pot.valid_totp(token, totp_secret(user), window: 1)

      _error ->
        false
    end
  end

  defp backup_code_valid?(user, token),
    do: Enum.any?(user.otp_backup_codes, &Password.verify_pass(token, &1))

  defp remove_backup_code(user, token),
    do: user.otp_backup_codes |> Enum.reject(&Password.verify_pass(token, &1))
end
