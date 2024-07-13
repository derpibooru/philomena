defmodule Philomena.ArtistLinks.ArtistLink do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Tags.Tag

  schema "artist_links" do
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

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(artist_link, attrs) do
    artist_link
    |> cast(attrs, [])
    |> validate_required([])
  end

  def edit_changeset(artist_link, attrs, nil) do
    artist_link
    |> cast(attrs, [:uri, :public])
    |> put_change(:tag_id, nil)
    |> validate_required([:user, :uri, :public])
    |> parse_uri()
  end

  def edit_changeset(artist_link, attrs, tag) do
    artist_link
    |> cast(attrs, [:uri, :public])
    |> put_change(:tag_id, tag.id)
    |> validate_required([:user, :uri, :public])
    |> parse_uri()
  end

  def creation_changeset(artist_link, attrs, user, tag) do
    artist_link
    |> cast(attrs, [:uri, :public])
    |> put_assoc(:tag, tag)
    |> put_assoc(:user, user)
    |> validate_required([:user, :uri, :public])
    |> validate_required([:tag], message: "must exist")
    |> validate_format(:uri, ~r|\Ahttps?://|)
    |> validate_category()
    |> parse_uri()
    |> put_verification_code()
    |> put_next_check_at()
    |> unique_constraint([:uri, :tag_id, :user_id],
      name: :index_artist_links_on_uri_tag_id_user_id
    )
  end

  def validate_category(changeset) do
    tag = get_field(changeset, :tag)

    if not is_nil(tag) and tag.category not in ["origin", "content-fanmade"] do
      add_error(changeset, :tag, "must be a creator tag")
    else
      changeset
    end
  end

  def reject_changeset(artist_link) do
    change(artist_link, aasm_state: "rejected")
  end

  def automatic_verify_changeset(artist_link, attrs) do
    cast(artist_link, attrs, [:next_check_at, :aasm_state])
  end

  def verify_changeset(artist_link, user) do
    change(artist_link)
    |> put_change(:verified_by_user_id, user.id)
    |> put_change(:aasm_state, "verified")
  end

  def contact_changeset(artist_link, user) do
    artist_link
    |> change()
    |> put_change(:contacted_by_user_id, user.id)
    |> put_change(:contacted_at, DateTime.utc_now(:second))
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
      :second
      |> DateTime.utc_now()
      |> DateTime.add(60 * 2, :second)

    change(changeset, next_check_at: time)
  end
end
