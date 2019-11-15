defmodule Philomena.Users.User do
  alias Philomena.Users.Password

  use Ecto.Schema

  use Pow.Ecto.Schema,
    password_hash_methods: {&Password.hash_pwd_salt/1, &Password.verify_pass/2},
    password_min_length: 6

  use Pow.Extension.Ecto.Schema,
    extensions: [PowResetPassword, PowLockout, PowPersistentSession]

  import Ecto.Changeset

  @derive {Phoenix.Param, key: :slug}

  schema "users" do
    has_many :links, Philomena.Users.Link
    has_many :verified_links, Philomena.Users.Link, where: [aasm_state: "verified"]
    has_many :public_links, Philomena.Users.Link, where: [public: true, aasm_state: "verified"]
    has_many :galleries, Philomena.Galleries.Gallery, foreign_key: :creator_id
    has_many :awards, Philomena.Badges.Award

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
    field :authentication_token, :string
    # field :failed_attempts, :integer
    # field :unlock_token, :string
    # field :locked_at, :naive_datetime
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
    |> pow_extension_changeset(attrs)
    |> cast(attrs, [])
    |> validate_required([])
  end

  def filter_changeset(user, filter) do
    change(user)
    |> put_change(:current_filter_id, filter.id)
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
    changeset = change(changeset, %{})
    user = changeset.data
    token = extract_token(params)

    case user.otp_required_for_login do
      true ->
        # User wants to disable TOTP
        changeset
        |> pow_password_changeset(params)
        |> consume_totp_token_changeset(token)
        |> disable_totp_changeset()

      _falsy ->
        # User wants to enable TOTP
        changeset
        |> pow_password_changeset(params)
        |> consume_totp_token_changeset(token)
        |> enable_totp_changeset(backup_codes)
    end
  end

  def random_backup_codes do
    (1..10)
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
      query: URI.encode_query(%{
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


  defp enable_totp_changeset(user, backup_codes) do
    hashed_codes =
      backup_codes
      |> Enum.map(&Password.hash_pwd_salt/1)

    user
    |> change(%{
      otp_required_for_login: true,
      otp_backup_codes: hashed_codes
    })
  end

  defp disable_totp_changeset(user) do
    user
    |> change(%{
      otp_required_for_login: false,
      otp_backup_codes: []
    })
  end

  defp extract_token(%{"user" => %{"twofactor_token" => t}}),
    do: to_string(t)

  defp extract_token(_params),
    do: ""

  defp totp_valid?(user, token),
    do: :pot.valid_totp(token, totp_secret(user), window: 1)

  defp backup_code_valid?(user, token),
    do: Enum.any?(user.otp_backup_codes, &Password.verify_pass(token, &1))

  defp remove_backup_code(user, token),
    do: user.otp_backup_codes |> Enum.reject(&Password.verify_pass(token, &1))
end