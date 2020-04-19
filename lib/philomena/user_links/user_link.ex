defmodule Philomena.UserLinks.UserLink do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Tags.Tag

  schema "user_links" do
    belongs_to :user, User
    belongs_to :verified_by_user, User
    belongs_to :contacted_by_user, User
    belongs_to :tag, Tag

    field :aasm_state, :string, default: "unverified"
    field :uri, :string
    field :hostname, :string
    field :path, :string
    field :verification_code, :string
    field :public, :boolean, default: true
    field :next_check_at, :utc_datetime
    field :contacted_at, :utc_datetime

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(user_link, attrs) do
    user_link
    |> cast(attrs, [])
    |> validate_required([])
  end

  def edit_changeset(user_link, attrs, nil) do
    user_link
    |> cast(attrs, [:uri, :public])
    |> put_change(:tag_id, nil)
    |> validate_required([:user, :uri, :public])
    |> parse_uri()
  end

  def edit_changeset(user_link, attrs, tag) do
    user_link
    |> cast(attrs, [:uri, :public])
    |> put_change(:tag_id, tag.id)
    |> validate_required([:user, :uri, :public])
    |> parse_uri()
  end

  def creation_changeset(user_link, attrs, user, tag) do
    user_link
    |> cast(attrs, [:uri, :public])
    |> put_assoc(:tag, tag)
    |> put_assoc(:user, user)
    |> validate_required([:user, :uri, :public])
    |> validate_format(:uri, ~r|\Ahttps?://|)
    |> parse_uri()
    |> put_verification_code()
    |> put_next_check_at()
  end

  def reject_changeset(user_link) do
    change(user_link, aasm_state: "rejected")
  end

  def verify_changeset(user_link, user) do
    change(user_link)
    |> put_change(:verified_by_user_id, user.id)
    |> put_change(:aasm_state, "verified")
  end

  def contact_changeset(user_link, user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    change(user_link)
    |> put_change(:contacted_by_user_id, user.id)
    |> put_change(:contacted_at, now)
    |> put_change(:aasm_state, "contacted")
  end

  defp parse_uri(changeset) do
    string_uri = get_field(changeset, :uri) |> to_string()
    uri = URI.parse(string_uri)

    changeset
    |> change(hostname: uri.host, path: uri.path)
  end

  defp put_verification_code(changeset) do
    code = :crypto.strong_rand_bytes(5) |> Base.encode16()
    change(changeset, verification_code: "DERPI-LINKVALIDATION-#{code}")
  end

  defp put_next_check_at(changeset) do
    time =
      DateTime.utc_now()
      |> DateTime.add(60 * 2, :second)
      |> DateTime.truncate(:second)

    change(changeset, next_check_at: time)
  end
end
