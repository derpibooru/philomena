defmodule Philomena.Users.User do
  alias Philomena.Users.Password
  alias Philomena.Slug

  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Schema.Approval

  alias Philomena.Filters.Filter
  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.Badges
  alias Philomena.Galleries.Gallery
  alias Philomena.Users.User
  alias Philomena.Users.Settings
  alias Philomena.Commissions.Commission
  alias Philomena.Roles.Role
  alias Philomena.Reports.Report
  alias Philomena.UserFingerprints.UserFingerprint
  alias Philomena.UserIps.UserIp
  alias Philomena.Bans
  alias Philomena.Donations.Donation
  alias Philomena.UserNameChanges.UserNameChange
  alias Philomena.Tags.Tag

  @type t :: %__MODULE__{}

  @derive {Phoenix.Param, key: :slug}
  @derive {Inspect, except: [:password]}
  schema "users" do
    has_many :links, ArtistLink
    has_many :verified_links, ArtistLink, where: [aasm_state: "verified"]
    has_many :public_links, ArtistLink, where: [public: true, aasm_state: "verified"]
    has_many :galleries, Gallery, foreign_key: :user_id
    has_many :awards, Badges.Award
    has_many :linked_tags, through: [:verified_links, :tag]
    has_many :user_ips, UserIp
    has_many :user_fingerprints, UserFingerprint
    has_many :bans, Bans.User
    has_many :donations, Donation
    has_one :commission, Commission
    many_to_many :roles, Role, join_through: "users_roles", on_replace: :delete
    has_many :name_changes, UserNameChange
    has_one :settings, Settings, on_replace: :update
    has_many :reports, Report, foreign_key: :reported_user_id
    has_many :created_reports, Report, foreign_key: :user_id

    belongs_to :current_filter, Filter
    belongs_to :forced_filter, Filter
    belongs_to :deleted_by_user, User

    # Authentication
    field :email, :string
    field :password, :string, virtual: true
    field :encrypted_password, :string
    field :hashed_password, :string, source: :encrypted_password
    field :confirmed_at, :utc_datetime
    field :otp_required_for_login, :boolean
    field :authentication_token, :string
    field :failed_attempts, :integer
    # field :unlock_token, :string
    field :locked_at, :utc_datetime
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
    field :personal_title, :string
    field :hide_advertisements, :boolean, default: false

    # Counters
    field :posts_count, :integer, default: 0
    field :topics_count, :integer, default: 0
    field :images_count, :integer, default: 0
    field :image_votes_count, :integer, default: 0
    field :comments_count, :integer, default: 0
    field :metadata_updates_count, :integer, default: 0
    field :image_faves_count, :integer, default: 0

    # Poorly denormalized associations
    field :recent_filter_ids, {:array, :integer}, default: []
    field :watched_tag_ids, {:array, :integer}, default: []
    field :watched_tag_list, :string, virtual: true

    # Other stuff
    field :last_renamed_at, :utc_datetime
    field :deleted_at, :utc_datetime
    field :scratchpad, :string
    field :secondary_role, :string
    field :hide_default_role, :boolean, default: false
    field :senior_staff, :boolean, default: false
    field :bypass_rate_limits, :boolean, default: false
    field :verified, :boolean, default: false

    # For avatar validation/persistence
    field :avatar_width, :integer, virtual: true
    field :avatar_height, :integer, virtual: true
    field :avatar_size, :integer, virtual: true
    field :avatar_mime_type, :string, virtual: true
    field :uploaded_avatar, :string, virtual: true
    field :removed_avatar, :string, virtual: true
    field :became_unapproved?, :boolean, virtual: true, default: false

    # For authorization
    field :role_map, :any, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.
  """
  def registration_changeset(user, password_compromised_fn, attrs)
      when is_function(password_compromised_fn, 1) do
    user
    |> cast(attrs, [:name, :email, :password])
    |> validate_name()
    |> validate_email()
    |> validate_password(password_compromised_fn)
    |> put_api_key()
    |> put_slug()
    |> unique_constraints()
    |> put_assoc(:settings, %Settings{})
  end

  defp validate_name(changeset) do
    changeset
    |> update_change(:name, &trim_name/1)
    |> validate_required([:name])
    |> validate_length(:name, max: 50)
  end

  # `cast/3` turns a submitted `""` into a change to nil, which
  # `validate_required/2` below reports.
  defp trim_name(nil), do: nil
  defp trim_name(name), do: String.trim(name)

  defp validate_email(changeset) do
    # The unsafe_validate_unique is used to generate form errors
    # when users generate an update token with an email that has
    # already been taken. It is not used to prevent duplicate
    # registrations - that is done with a real unique constraint.

    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/\A[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}\z/,
      message: "must be valid (e.g., user@example.com)"
    )
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Philomena.Repo)
  end

  defp validate_password(changeset, password_compromised_fn) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 80)
    |> validate_compromised_password(password_compromised_fn)
    |> prepare_changes(&hash_password/1)
  end

  defp validate_compromised_password(
         %Ecto.Changeset{valid?: true} = changeset,
         password_compromised_fn
       ) do
    validate_change(changeset, :password, fn :password, password ->
      if password_compromised_fn.(password) do
        [password: "has been compromised in a data breach"]
      else
        []
      end
    end)
  end

  defp validate_compromised_password(changeset, _password_compromised_fn), do: changeset

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
  def password_changeset(user, password_compromised_fn, attrs)
      when is_function(password_compromised_fn, 1) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(password_compromised_fn)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    change(user, confirmed_at: DateTime.utc_now(:second))
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
    failed_attempts = max(0, user.failed_attempts || 0) + 1
    changeset = change(user, failed_attempts: failed_attempts)

    if failed_attempts >= 10 do
      lock_changeset(changeset)
    else
      changeset
    end
  end

  def lock_changeset(user) do
    change(user, locked_at: DateTime.utc_now(:second))
  end

  def unlock_changeset(user) do
    change(user, locked_at: nil, failed_attempts: 0)
  end

  def changeset(user, attrs \\ %{}) do
    cast(user, attrs, [])
  end

  def update_changeset(user, attrs, roles) do
    user
    |> cast(attrs, [
      :name,
      :email,
      :role,
      :secondary_role,
      :hide_default_role,
      :senior_staff,
      :bypass_rate_limits
    ])
    |> validate_required([:name, :email, :role])
    |> validate_inclusion(:role, ["user", "assistant", "moderator", "admin"])
    |> validate_name()
    |> validate_email()
    |> put_assoc(:roles, roles)
    |> put_slug()
    |> unique_constraints()
  end

  def role_error_changeset(user) do
    user
    |> change()
    |> add_error(:roles, "contains an invalid role")
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

  def settings_changeset(user, attrs) do
    user
    |> cast(attrs, [:watched_tag_list])
    |> cast_assoc(:settings, with: &Settings.changeset(&1, &2, user))
  end

  @doc false
  def watched_tag_names(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:watched_tag_list])
    |> get_field(:watched_tag_list)
    |> Tag.parse_tag_list()
  end

  @doc false
  def put_watched_tag_ids(changeset, watched_tag_ids) do
    put_change(changeset, :watched_tag_ids, watched_tag_ids)
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
    |> maybe_put_description_approval(user)
  end

  defp maybe_put_description_approval(%{valid?: true} = changeset, user) do
    was_approved? =
      Approval.approved?(user, user.description, :external_links) and
        Approval.approved?(user, user.personal_title, :external_links)

    approved? =
      Approval.approved?(user, get_field(changeset, :description), :external_links) and
        Approval.approved?(user, get_field(changeset, :personal_title), :external_links)

    change(changeset, became_unapproved?: was_approved? and not approved?)
  end

  defp maybe_put_description_approval(changeset, _user), do: changeset

  def scratchpad_changeset(user, attrs) do
    user
    |> cast(attrs, [:scratchpad])
  end

  def name_changeset(user, attrs) do
    user
    |> cast(attrs, [:name])
    |> validate_name()
    |> put_slug()
    |> unique_constraints()
    |> put_change(:last_renamed_at, DateTime.utc_now(:second))
  end

  def avatar_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :avatar,
      :avatar_width,
      :avatar_height,
      :avatar_size,
      :avatar_mime_type,
      :uploaded_avatar,
      :removed_avatar
    ])
    |> validate_required([
      :avatar,
      :avatar_width,
      :avatar_height,
      :avatar_size,
      :avatar_mime_type,
      :uploaded_avatar
    ])
    |> validate_number(:avatar_size, greater_than: 0, less_than_or_equal_to: 512_000)
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
    changeset = change(user)

    if get_field(changeset, :deleted_at) do
      change(user, deleted_at: nil, deleted_by_user_id: nil)
    else
      add_error(changeset, :deleted_at, "is already active")
    end
  end

  def erase_changeset(user, name, deactivator) do
    changeset = name_changeset(user, %{"name" => name})

    if get_field(changeset, :deleted_at) do
      changeset
    else
      now = DateTime.utc_now(:second)
      change(changeset, deleted_at: now, deleted_by_user_id: deactivator.id)
    end
  end

  def deactivate_changeset(user, deactivator) do
    changeset = change(user)

    if get_field(changeset, :deleted_at) do
      add_error(changeset, :deleted_at, "is already deactivated")
    else
      now = DateTime.utc_now(:second)
      change(user, deleted_at: now, deleted_by_user_id: deactivator.id)
    end
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

  def verify_changeset(user) do
    change(user, verified: true)
  end

  def unverify_changeset(user) do
    change(user, verified: false)
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
        change(changeset, consumed_timestep: String.to_integer(token))

      backup_code_valid?(user, token) ->
        change(changeset, otp_backup_codes: remove_backup_code(user, token))

      true ->
        add_error(changeset, :twofactor_token, "Invalid token")
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
      path: "/Derpibooru:" <> user.email,
      query:
        URI.encode_query(%{
          secret: secret,
          issuer: "Derpibooru"
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

  def clear_recent_filters_changeset(user) do
    user
    |> change(%{
      recent_filter_ids: [user.current_filter_id]
    })
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
    |> unique_constraint(:name, name: :index_users_on_lower_name)
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

  defp totp_valid?(%{encrypted_otp_secret: nil}, _token), do: false

  defp totp_valid?(user, token) do
    case Integer.parse(token) do
      {int_token, _rest} ->
        int_token != user.consumed_timestep and
          :pot.valid_totp(token, totp_secret(user), window: 1)

      _error ->
        false
    end
  end

  defp backup_code_valid?(%{otp_backup_codes: nil}, _token), do: false

  defp backup_code_valid?(user, token),
    do: Enum.any?(user.otp_backup_codes, &Password.verify_pass(token, &1))

  defp remove_backup_code(user, token),
    do: user.otp_backup_codes |> Enum.reject(&Password.verify_pass(token, &1))
end
